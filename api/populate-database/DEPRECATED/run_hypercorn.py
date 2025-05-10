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
from flask import request
from hypercorn.config import Config
from hypercorn.asyncio import serve
from flask_limiter import Limiter

from asgiref.wsgi import WsgiToAsgi

# Import the Flask application
from main import app, limiter

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

@app.before_request
def log_request_info():
    logger.info(f"Received request: {request.method} {request.path}")

# Add a test route at the root
@app.route("/", methods=["GET"])
@limiter.exempt
def root_endpoint():
    """Root endpoint for testing"""
    routes = [str(rule.rule) for rule in app.url_map.iter_rules() 
              if not str(rule.rule).startswith("/static")]
    return jsonify({
        "status": "ok",
        "message": "TikTok Processing API is running",
        "available_routes": routes
    }), 200

# Make sure all routes are registered
app.url_map.update()

# Print all registered routes
print("\nRegistered Routes:")
for rule in app.url_map.iter_rules():
    print(f"Route: {rule.rule}, Methods: {rule.methods}")

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

        try:
            from uvicorn.middleware.wsgi import WSGIMiddleware
            asgi_app = WSGIMiddleware(app)
            logger.info("Using Uvicorn's WSGIMiddleware for ASGI conversion")
        except ImportError:
            # Fall back to asgiref if uvicorn is not available
            logger.warning("Uvicorn not available, using asgiref's WsgiToAsgi instead")
            from asgiref.wsgi import WsgiToAsgi
            asgi_app = WsgiToAsgi(app)

        # Log server startup
        logger.info(f"Starting Hypercorn server on {host}:{port}")
        logger.info("Test the API with: curl http://localhost:8080/health")
        logger.info("Press Ctrl+C to stop the server")

        # Run the server with the ASGI app
        await serve(asgi_app, config)

    except Exception as e:
        logger.error(f"Error starting Hypercorn server: {e}")
        raise

if __name__ == "__main__":
    logger.info("Registered Flask routes:")
    for rule in app.url_map.iter_rules():
        logger.info(f"Route: {rule.rule}, Methods: {rule.methods}, Endpoint: {rule.endpoint}")
    
    # Run the server
    asyncio.run(run_server())