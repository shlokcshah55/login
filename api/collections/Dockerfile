# Use Python 3.11 slim image for smaller size
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY main.py .
COPY api.py .
COPY prompt.txt .

# Expose port 8080 (Cloud Run default)
EXPOSE 8080

# Set environment variable for production
ENV PYTHONUNBUFFERED=1

# Run the Flask app with gunicorn for production
CMD ["sh", "-c", "exec gunicorn --bind :$PORT --workers 1 --threads 8 --timeout 0 api:app"]
