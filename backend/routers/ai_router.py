from io import BytesIO

from fastapi import APIRouter, File, Form, HTTPException, UploadFile

try:
    from PIL import Image, UnidentifiedImageError
except ImportError:  # pragma: no cover
    Image = None
    UnidentifiedImageError = Exception

from services.yolo_face_service import yolo_face_service

router = APIRouter(prefix="/ai", tags=["AI"])


@router.post("/detect-faces")
async def detect_faces(
    file: UploadFile = File(...),
    confidence_threshold: float = Form(0.50),
    iou_threshold: float = Form(0.60),
):
    if not yolo_face_service.is_available:
        raise HTTPException(
            status_code=503,
            detail=(
                "Interpreter TFLite belum tersedia di backend. "
                "Install tflite-runtime atau tensorflow."
            ),
        )

    try:
        image_bytes = await file.read()
        if Image is None:
            raise RuntimeError("Pillow belum tersedia di backend")
        image = Image.open(BytesIO(image_bytes))
        return yolo_face_service.detect_faces(
            image,
            confidence_threshold=confidence_threshold,
            iou_threshold=iou_threshold,
        )
    except UnidentifiedImageError:
        raise HTTPException(status_code=400, detail="File gambar tidak valid")
    except FileNotFoundError as error:
        raise HTTPException(status_code=500, detail=str(error))
    except RuntimeError as error:
        raise HTTPException(status_code=503, detail=str(error))
    finally:
        await file.close()
