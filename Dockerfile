# Use the Playwright base image (includes browser dependencies)
FROM mcr.microsoft.com/playwright:focal

# Set environment variables to use system browsers and disable headless warnings
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
ENV PLAYWRIGHT_HEADLESS=true

# Set the working directory inside the container
WORKDIR /functions

# Install system dependencies
RUN apt-get update && apt-get install -y \
    software-properties-common \
    && add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get update \
    && apt-get install -y \
       python3.12 \
       python3.12-venv \
       python3.12-dev \
       python3-pip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set Python 3.12 as default
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1

# Ensure venv is available
RUN python3 -m ensurepip

# Copy project files (functions folder)
COPY . /functions

EXPOSE 8080

# Create and activate a virtual environment inside the functions directory
RUN python3 -m venv venv

# Install Python dependencies
RUN venv/bin/pip install --no-cache-dir -r requirements.txt

# Install Playwright Python package and connect to system browsers
RUN venv/bin/pip install playwright==1.42.0


# Set the default command to run your Firebase function script
CMD ["venv/bin/python3", "main.py"]