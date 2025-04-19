"""
Hypercorn runner for the TikTok Processing API.
This script runs the API server with Hypercorn to support HTTP/2.0.

creates an Asyncronous server gateway interface (ASGI) server using Hypercorn.
This allows asynchronous web frameworks like Flask to run in an asynchronous environment.
It uses the Hypercorn server to serve the Flask application defined in main.py.
"""
import os
import asyncio
import logging
from dotenv import load_dotenv
from hypercorn.config import Config
from hypercorn.asyncio import serve

# Import the Flask application
from main import app

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

async def run_server():
    """Run the API server with Hypercorn."""
    try:
        # Get configuration from environment variables or use defaults
        port = int(os.environ.get("PORT", 8080))
        host = os.environ.get("HOST", "0.0.0.0")
        
        # Configure Hypercorn
        config = Config()
        config.bind = [f"{host}:{port}"]
        config.alpn_protocols = ["h2", "http/1.1"]  # Support both HTTP/2 and HTTP/1.1
        config.use_reloader = True if os.environ.get("DEBUG", "False").lower() == "true" else False
        config.access_log_format = '%(h)s %(r)s %(s)s %(b)s %(D)s'
        config.accesslog = '-'  # Log to stdout
        config.errorlog = '-'   # Log errors to stdout
        
        # Log server startup
        logger.info(f"Starting Hypercorn server on {host}:{port} with HTTP/2.0 support")
        logger.info("Press Ctrl+C to stop the server")
        
        # Run the server
        await serve(app, config)
        
    except Exception as e:
        logger.error(f"Error starting Hypercorn server: {e}")
        raise

if __name__ == "__main__":
    # Run the server
    asyncio.run(run_server())