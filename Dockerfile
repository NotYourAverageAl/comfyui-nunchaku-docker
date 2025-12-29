# ==========================================
# STAGE 1: Builder (Compilation & Installation)
# ==========================================
FROM nvidia/cuda:12.4.1-devel-ubuntu22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git wget bzip2 ca-certificates ninja-build && \
    rm -rf /var/lib/apt/lists/*

# Install Miniconda
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh && \
    /bin/bash ~/miniconda.sh -b -p /opt/conda && \
    rm ~/miniconda.sh

ENV PATH="/opt/conda/bin:$PATH"

# FIX: Accept Conda ToS and Create Environment
RUN conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r && \
    conda create -n comfy python=3.12 -y

# Use the environment for subsequent steps
SHELL ["conda", "run", "-n", "comfy", "/bin/bash", "-c"]

# Install PyTorch
RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124

# Set up ComfyUI and Custom Nodes
WORKDIR /opt
RUN git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git

# Clone Custom Nodes (Manager + Nunchaku + Sage Source)
RUN git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git ComfyUI/custom_nodes/ComfyUI-Manager && \
    git clone --depth 1 https://github.com/nunchaku-tech/ComfyUI-nunchaku.git ComfyUI/custom_nodes/ComfyUI-nunchaku && \
    git clone --depth 1 https://github.com/thu-ml/SageAttention.git

# Install Nunchaku (latest stable)
RUN pip install nunchaku --extra-index-url https://download.pytorch.org/whl/cu124

# Install Requirements
RUN pip install -r ComfyUI/requirements.txt && \
    pip install -r ComfyUI/custom_nodes/ComfyUI-Manager/requirements.txt && \
    pip install -r ComfyUI/custom_nodes/ComfyUI-nunchaku/requirements.txt && \
    pip install pilgram evalidate

# Compile SageAttention
WORKDIR /opt/SageAttention
RUN export EXT_PARALLEL=1 NVCC_APPEND_FLAGS="--threads 1" MAX_JOBS=1 TORCH_CUDA_ARCH_LIST="8.0;8.6;8.9;9.0" && \
    pip install . --no-build-isolation

# ==========================================
# STAGE 2: Runtime (Minimal Production Image)
# ==========================================
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 libglib2.0-0 ffmpeg curl git vim && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy Conda environment and ComfyUI from builder
COPY --from=builder /opt/conda /opt/conda
COPY --from=builder /opt/ComfyUI /workspace/ComfyUI

# Set paths
ENV PATH="/opt/conda/envs/comfy/bin:/opt/conda/bin:$PATH"
ENV LD_LIBRARY_PATH="/opt/conda/envs/comfy/lib:$LD_LIBRARY_PATH"

WORKDIR /workspace
COPY start.sh .
RUN chmod +x /workspace/start.sh

EXPOSE 8188
CMD ["/workspace/start.sh"]
