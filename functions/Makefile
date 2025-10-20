# Makefile for Firebase Functions (Python)
# ------------------------------------------
# Available targets:
#
#   make help      - Show this help message
#   make install   - Install Python dependencies from requirements.txt
#   make deploy    - Deploy Firebase Functions using the Firebase CLI
#   make test      - Run tests (using pytest in this example)
#   make clean     - Remove Python cache and temporary files
# ------------------------------------------

.PHONY: help install deploy test clean

help:
	@echo "Makefile commands:"
	@echo "  make install   - Install Python dependencies"
	@echo "  make deploy    - Deploy Firebase Functions"
	@echo "  make test      - Run tests"
	@echo "  make clean     - Clean build artifacts"

install:
	@echo "Installing dependencies..."
	pip3 install -r requirements.txt
	python3 -m playwright install

deploy:
	@echo "Deploying Firebase Functions..."
	firebase deploy --only functions

test:
	@echo "Running tests..."
	pytest

clean:
	@echo "Cleaning up..."
	# Remove Python cache directories and compiled files
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
