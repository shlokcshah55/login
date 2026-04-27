# Use official Python runtime as base image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Expose port (Cloud Run uses PORT env var)
ENV PORT=8080
EXPOSE 8080

# Run the application with gunicorn for production
# High timeout needed for Apify scraping jobs which can take 2-5 minutes
CMD exec gunicorn --bind :$PORT --workers 2 --threads 2 --timeout 600 main:app
