# Use the Playwright Python image which already includes both Python and browser dependencies
FROM mcr.microsoft.com/playwright/python:v1.42.0-jammy

# Set environment variables for Playwright
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
ENV PLAYWRIGHT_HEADLESS=true

# Set the working directory inside the container
WORKDIR /functions

# Copy requirements first to leverage Docker caching
COPY functions/requirements.txt .

# Add required packages to requirements.txt
RUN printf "\nplaywright>=1.40.0\nfunctions-framework>=3.0.0\n" >> requirements.txt

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Install Playwright browsers explicitly to ensure they're available
RUN playwright install chromium

# Copy only the functions directory content
COPY functions/ .

# Create and chmod the cache directory for playwright
# This is crucial for the Firebase Functions environment
RUN mkdir -p /www-data-home/.cache
RUN chmod -R 777 /www-data-home

# Expose the port used by Firebase Functions
EXPOSE 8080

# Use functions-framework to run the Firebase Functions service
CMD ["python", "-m", "functions_framework", "--target=process_tiktok_link", "--signature-type=http"]