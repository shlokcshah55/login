# Use the latest Playwright Python image which already includes both Python and browser dependencies
FROM mcr.microsoft.com/playwright/python:v1.42.0-jammy

# Set environment variables for Playwright and Python
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
ENV PLAYWRIGHT_HEADLESS=true
ENV PYTHONUNBUFFERED=1
ENV PORT=8080
ENV HOST=0.0.0.0

# Set working directory
WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt && \
    pip install hypercorn

# Create directory for credentials (will be mounted at runtime)
RUN mkdir -p /secrets

# Copy only the application code - NOT credentials
COPY *.py ./
COPY .env.template .env.template
COPY utils/ utils/

# Install additional Playwright dependencies (specifically for TikTok-Api)
RUN playwright install chromium

# Create and chmod the cache directory for playwright
# This is crucial for the TikTok-Api to function correctly
RUN mkdir -p /root/.cache
RUN chmod -R 777 /root/.cache

# Expose the port for the API
EXPOSE 8080

# Run the main application
CMD ["python", "main.py"]

