#!/bin/bash
# script to create a model artifact for SageMaker inference

set -e # Exit on error
set -u # Exit on undefined variable
# set -x # Print commands

# handy function to download files from hugging face
# usage: download_huggingface <url> <target folder>
download_huggingface() {
    # first wget with --no-clobber, then wget with --timestamping
    wget -nc "$1" -P "$2" || wget -N "$1" -P "$2"
    # wget --header="Authorization: Bearer ${HF_TOKEN}" -nc "$1" -P "$2" || wget --header="Authorization: Bearer ${HF_TOKEN}" -N "$1" -P "$2"
}

# target folder for downloading model artifact
TARGET_DIR="model-artifact"

# target file for tar-gzip archive of model artifact
TARGET_FILE="model-artifact.tgz"

show_usage() {
    echo "Usage: $0 [s3://path/to/s3/object]"
    exit 1
}
# s3 upload path (optional)
S3_PATH=""
if [ "$#" -gt 1 ]; then
    show_usage
elif [ "$#" -eq 1 ]; then
    if [[ "$1" == s3://* ]]; then
        S3_PATH="$1"
    else
        show_usage
    fi
fi

# initialize empty folder structure
mkdir -p "${TARGET_DIR}"
DIRS=(checkpoints clip clip_vision configs controlnet embeddings loras upscale_models vae gligen custom_nodes unet)
for dir in "${DIRS[@]}"
do
    mkdir -p "${TARGET_DIR}/${dir}"
done

# download models that you want to include
# stable-diffusion-xl-base-1.0 
cp /home/backstage/ComfyUI/models/checkpoints/leosamsHelloworldXL_helloworldXL70.safetensors "${TARGET_DIR}/checkpoints/"
cp /home/backstage/ComfyUI/models/controlnet/control-lora-depth-rank256.safetensors "${TARGET_DIR}/controlnet/"
cp /home/backstage/ComfyUI/models/controlnet/control-lora-canny-rank256.safetensors "${TARGET_DIR}/controlnet/"

cd ${TARGET_DIR}/custom_nodes
[[ -e ComfyUI-Manager ]] || git clone https://github.com/ltdrdata/ComfyUI-Manager.git && (cd ComfyUI-Manager ; git reset --hard 90ae9af6ed2f80343defedb92ac61c79d4dbdc33)
cd -
cd ${TARGET_DIR}/custom_nodes
git clone https://github.com/john-mnz/ComfyUI-Inspyrenet-Rembg && (cd ComfyUI-Inspyrenet-Rembg ; pip install -r requirements.txt)
cd -

# Flux Dev (fp8 checkpoint version)
# Ref: https://comfyanonymous.github.io/ComfyUI_examples/flux/#flux-dev-1
# download_huggingface 'https://huggingface.co/Comfy-Org/flux1-dev/resolve/main/flux1-dev-fp8.safetensors' "${TARGET_DIR}/checkpoints"

# Flux Schnell (fp8 checkpoint version)
# Ref: https://comfyanonymous.github.io/ComfyUI_examples/flux/#flux-schnell-1
# download_huggingface 'https://huggingface.co/Comfy-Org/flux1-schnell/resolve/main/flux1-schnell-fp8.safetensors' "${TARGET_DIR}/checkpoints"

# black-forest-labs/FLUX.1-dev (requires authentication)
# download_huggingface 'https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors' "${TARGET_DIR}/unet" 
# download_huggingface 'https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors' "${TARGET_DIR}/vae"
# download_huggingface 'https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors' "${TARGET_DIR}/clip"
# download_huggingface 'https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors' "${TARGET_DIR}/clip"

# black-forest-labs/FLUX.1-schnell (requires authentication)
# download_huggingface 'https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/flux1-schnell.safetensors' "${TARGET_DIR}/unet" 
# download_huggingface 'https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors' "${TARGET_DIR}/vae"
# download_huggingface 'https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors' "${TARGET_DIR}/clip"
# download_huggingface 'https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors' "${TARGET_DIR}/clip"

# ComfyUI-Manager - extension to manage custom nodes
# cd ${TARGET_DIR}/custom_nodes
# [[ -e ComfyUI-Manager ]] || git clone https://github.com/ltdrdata/ComfyUI-Manager.git && (cd ComfyUI-Manager && git fetch && git checkout 2.48.6)
# cd -
>>>>>>> 79bc7788fb5f632077210c7a2ca9eebd8a4c05d2

if [ -z "${S3_PATH}" ]; then
    exit 0
fi
echo "Creating ${TARGET_FILE}..."
# tar gzip the folder and upload to S3
if [ -n "$(which pigz)" ]; then
    # use pigz to speed up compression on multiple cores
    tar -cv -C "${TARGET_DIR}" . | pigz -1 > "${TARGET_FILE}"
else
    # tar is slower
    tar -czvf ${TARGET_FILE} -C ${TARGET_DIR} .
fi
echo "Uploading ${S3_PATH}..."
aws s3 cp "${TARGET_FILE}" "${S3_PATH}"
