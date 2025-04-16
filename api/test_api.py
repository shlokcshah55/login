#!/usr/bin/env python3
"""
Test script for the TikTok processing API.
This script sends a request to the local API server to test the /process-tiktok endpoint.
"""
import requests
import json
import argparse
import logging
import urllib3
import os
import time
import sys

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def create_session(http2=False):
    """
    Create a requests session with HTTP/2 support if needed.
    
    Args:
        http2: Whether to use HTTP/2 (requires requests-http2)
        
    Returns:
        A configured requests session
    """
    if http2:
        try:
            # Try to import HTTP/2 support if available
            from requests_http2 import HTTPAdapter
            session = requests.Session()
            session.mount('https://', HTTPAdapter())
            session.mount('http://', HTTPAdapter())
            logging.info("Using HTTP/2 for requests")
            return session
        except ImportError:
            logging.warning("requests-http2 package not found. Falling back to HTTP/1.1")
            # Continue with standard requests below
    
    # Standard HTTP/1.1 session
    session = requests.Session()
    logging.info("Using HTTP/1.1 for requests")
    return session

def test_process_tiktok(url, server_url="http://localhost:8080", http2=False, max_retries=3, retry_delay=2):
    """
    Test the /process-tiktok endpoint with a given TikTok URL.
    
    Args:
        url: The TikTok URL to process
        server_url: The base URL of the API server (default: http://localhost:8080)
        http2: Whether to use HTTP/2 for the request
        max_retries: Maximum number of connection retries
        retry_delay: Delay between retries in seconds
    """
    endpoint = f"{server_url}/process-tiktok"
    
    # Prepare request data
    data = {
        "url": url,
        "userId": "test-user"  # Optional test user ID
    }
    
    logging.info(f"Sending request to {endpoint} with URL: {url}")
    
    # Create appropriate session
    session = create_session(http2)
    
    # Send request to the API with retries
    for attempt in range(max_retries):
        try:
            response = session.post(
                endpoint,
                json=data,
                headers={
                    'Content-Type': 'application/json',
                    'Accept': 'application/json'
                },
                timeout=60  # Increased timeout for processing
            )
            
            # Check response
            logging.info(f"Response status code: {response.status_code}")
            
            if response.status_code >= 200 and response.status_code < 300:
                result = response.json()
                logging.info("Request successful!")
                print(json.dumps(result, indent=2))
                return result
            else:
                logging.error(f"Request failed with status {response.status_code}")
                logging.error(f"Response: {response.text}")
                return None
                
        except (requests.exceptions.RequestException, ConnectionError) as e:
            if attempt < max_retries - 1:
                logging.warning(f"Connection attempt {attempt+1} failed: {e}")
                logging.info(f"Retrying in {retry_delay} seconds...")
                time.sleep(retry_delay)
            else:
                logging.error(f"Error sending request after {max_retries} attempts: {e}")
                return None

def check_server_health(server_url="http://localhost:8080", http2=False):
    """
    Check if the server is running by hitting the health endpoint.
    
    Args:
        server_url: The base URL of the API server
        http2: Whether to use HTTP/2 for the request
        
    Returns:
        True if server is healthy, False otherwise
    """
    try:
        session = create_session(http2)
        response = session.get(f"{server_url}/health", timeout=5)
        if response.status_code == 200:
            logging.info(f"Server is healthy: {response.json()}")
            return True
        else:
            logging.warning(f"Server returned non-200 status: {response.status_code}")
            return False
    except Exception as e:
        logging.error(f"Failed to connect to server: {e}")
        return False

if __name__ == "__main__":
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='Test the TikTok processing API')
    parser.add_argument('url', help='The TikTok URL to process')
    parser.add_argument('--server', default='http://localhost:8080', 
                        help='The API server URL (default: http://localhost:8080)')
    parser.add_argument('--http2', action='store_true', 
                        help='Use HTTP/2 for the request (requires requests-http2 package)')
    parser.add_argument('--retries', type=int, default=3,
                        help='Maximum number of connection retries (default: 3)')
    
    args = parser.parse_args()
    
    # Check server health first
    if not check_server_health(args.server, args.http2):
        logging.error("Server appears to be down or unreachable. Make sure it's running.")
        sys.exit(1)
    
    # Run the test
    test_process_tiktok(args.url, args.server, args.http2, args.retries)