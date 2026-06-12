from __future__ import annotations

import os
import time
from pathlib import Path

try:
    import numpy as np
except ImportError:  # pragma: no cover
    np = None

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    Image = None

try:
    from ai_edge_litert.interpreter import Interpreter
except ImportError:  # pragma: no cover - fallback untuk runtime lama
    try:
        from tflite_runtime.interpreter import Interpreter
    except ImportError:  # pragma: no cover - fallback untuk environment TensorFlow penuh
        try:
            from tensorflow.lite.python.interpreter import Interpreter
        except ImportError:  # pragma: no cover
            Interpreter = None


class YoloFaceService:
    def __init__(self) -> None:
        self._interpreter = None
        self._input_details = None
        self._output_details = None

    @property
    def is_available(self) -> bool:
        return Interpreter is not None and np is not None and Image is not None

    def detect_faces(
        self,
        image: Image.Image,
        confidence_threshold: float = 0.50,
        iou_threshold: float = 0.60,
        max_boxes: int = 50,
    ) -> dict:
        if not self.is_available:
            raise RuntimeError(
                "Dependensi AI backend belum tersedia. Install numpy, pillow, "
                "dan ai-edge-litert, tflite-runtime, atau tensorflow."
            )

        timings: dict[str, int] = {}
        total_start = time.perf_counter()

        self._load()
        assert self._interpreter is not None
        assert self._input_details is not None
        assert self._output_details is not None

        input_detail = self._input_details[0]
        output_detail = self._output_details[0]
        _, input_height, input_width, _ = input_detail["shape"]

        image = image.convert("RGB")
        source_width, source_height = image.size

        resize_start = time.perf_counter()
        resized = image.resize((int(input_width), int(input_height)), Image.BILINEAR)
        timings["resize_ms"] = _elapsed_ms(resize_start)

        input_start = time.perf_counter()
        input_data = np.asarray(resized)
        if input_detail["dtype"] == np.float32:
            input_data = input_data.astype(np.float32) / 255.0
        else:
            input_data = input_data.astype(input_detail["dtype"])
        input_data = np.expand_dims(input_data, axis=0)
        timings["input_ms"] = _elapsed_ms(input_start)

        inference_start = time.perf_counter()
        self._interpreter.set_tensor(input_detail["index"], input_data)
        self._interpreter.invoke()
        output = self._interpreter.get_tensor(output_detail["index"])
        timings["inference_ms"] = _elapsed_ms(inference_start)

        decode_start = time.perf_counter()
        rows = _decode_rows(output, output_detail["shape"])
        candidates = []
        for row in rows:
            box = _decode_box(
                row,
                image_width=float(source_width),
                image_height=float(source_height),
                input_width=float(input_width),
                input_height=float(input_height),
                confidence_threshold=confidence_threshold,
            )
            if box is not None:
                candidates.append(box)
        timings["decode_ms"] = _elapsed_ms(decode_start)

        nms_start = time.perf_counter()
        selected = _non_max_suppression(candidates, iou_threshold, max_boxes)
        timings["nms_ms"] = _elapsed_ms(nms_start)
        timings["total_ms"] = _elapsed_ms(total_start)

        return {
            "image_width": source_width,
            "image_height": source_height,
            "candidates": len(candidates),
            "boxes": selected,
            "timings": timings,
        }

    def _load(self) -> None:
        if self._interpreter is not None:
            return

        model_path = _model_path()
        if not model_path.exists():
            raise FileNotFoundError(f"Model YOLO tidak ditemukan: {model_path}")

        self._interpreter = Interpreter(
            model_path=str(model_path),
            num_threads=int(os.getenv("YOLO_TFLITE_THREADS", "4")),
        )
        self._interpreter.allocate_tensors()
        self._input_details = self._interpreter.get_input_details()
        self._output_details = self._interpreter.get_output_details()


def _model_path() -> Path:
    env_path = os.getenv("YOLO_FACE_MODEL_PATH")
    if env_path:
        return Path(env_path)
    return Path(__file__).resolve().parents[1] / "ai_models" / "yolofacedetect.tflite"


def _elapsed_ms(start: float) -> int:
    return int((time.perf_counter() - start) * 1000)


def _decode_rows(output: np.ndarray, shape: list[int] | tuple[int, ...]) -> list[np.ndarray]:
    flat = output.reshape(-1)
    if len(shape) == 2:
        return _to_rows(flat, int(shape[0]), int(shape[1]))

    if len(shape) != 3 or int(shape[0]) != 1:
        return []

    first = int(shape[1])
    second = int(shape[2])
    if first <= 20 and second > first:
        attrs = first
        count = second
        if flat.size < attrs * count:
            return []
        matrix = flat[: attrs * count].reshape(attrs, count)
        return [matrix[:, index] for index in range(count)]

    return _to_rows(flat, first, second)


def _to_rows(flat: np.ndarray, rows: int, cols: int) -> list[np.ndarray]:
    if rows <= 0 or cols <= 0 or flat.size < rows * cols:
        return []
    matrix = flat[: rows * cols].reshape(rows, cols)
    return [matrix[row] for row in range(rows)]


def _decode_box(
    row: np.ndarray,
    image_width: float,
    image_height: float,
    input_width: float,
    input_height: float,
    confidence_threshold: float,
) -> dict | None:
    if row.size < 5:
        return None

    confidence = float(row[4])
    if row.size > 5:
        class_confidence = float(np.max(row[5:]))
        confidence = max(confidence, confidence * class_confidence)
    confidence = _normalize_score(confidence)
    if confidence < confidence_threshold:
        return None

    x = float(row[0])
    y = float(row[1])
    width_raw = abs(float(row[2]))
    height_raw = abs(float(row[3]))
    normalized = all(0 <= value <= 2 for value in (x, y, width_raw, height_raw))

    if normalized:
        width = width_raw * image_width
        height = height_raw * image_height
        left = (x * image_width) - width / 2
        top = (y * image_height) - height / 2
    else:
        scale_x = image_width / input_width
        scale_y = image_height / input_height
        width = width_raw * scale_x
        height = height_raw * scale_y
        left = (x * scale_x) - width / 2
        top = (y * scale_y) - height / 2

    left = float(np.clip(left, 0, image_width))
    top = float(np.clip(top, 0, image_height))
    width = float(np.clip(width, 0, image_width - left))
    height = float(np.clip(height, 0, image_height - top))
    if width < 12 or height < 12:
        return None

    return {
        "left": left,
        "top": top,
        "width": width,
        "height": height,
        "confidence": confidence,
    }


def _normalize_score(value: float) -> float:
    if 0 <= value <= 1:
        return value
    assert np is not None
    return float(1 / (1 + np.exp(-value)))


def _non_max_suppression(
    boxes: list[dict],
    iou_threshold: float,
    max_boxes: int,
) -> list[dict]:
    sorted_boxes = sorted(boxes, key=lambda item: item["confidence"], reverse=True)
    selected: list[dict] = []

    for box in sorted_boxes:
        if any(_iou(item, box) > iou_threshold for item in selected):
            continue
        selected.append(box)
        if len(selected) >= max_boxes:
            break

    return selected


def _iou(a: dict, b: dict) -> float:
    left = max(a["left"], b["left"])
    top = max(a["top"], b["top"])
    right = min(a["left"] + a["width"], b["left"] + b["width"])
    bottom = min(a["top"] + a["height"], b["top"] + b["height"])
    intersection = max(0.0, right - left) * max(0.0, bottom - top)
    union = a["width"] * a["height"] + b["width"] * b["height"] - intersection
    if union <= 0:
        return 0.0
    return float(intersection / union)


yolo_face_service = YoloFaceService()
