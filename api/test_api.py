#!/usr/bin/env python3
"""
Test script for the TikTok processing API.
This script sends a request to the local API server to test the /process-tiktok endpoint.
"""
import requests
import json
import argparse
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def test_process_tiktok(url, server_url="http://localhost:8080"):
    """
    Test the /process-tiktok endpoint with a given TikTok URL.
    
    Args:
        url: The TikTok URL to process
        server_url: The base URL of the API server (default: http://localhost:8080)
    """
    endpoint = f"{server_url}/process-tiktok"
    

    # Prepare request data
    data = {
        "url": url,
        "userId": "test-user"  # Optional test user ID - use oCyiXu6gT1ccAydnCZ5VXxugl5F3 for my userid
    }
    
    logging.info(f"Sending request to {endpoint} with URL: {url}")
    
    # Send request to the API
    try:
        response = requests.post(
            endpoint,
            json=data,
            headers={'Content-Type': 'application/json'}
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
            
    except requests.exceptions.RequestException as e:
        logging.error(f"Error sending request: {e}")
        return None

if __name__ == "__main__":
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='Test the TikTok processing API')
    parser.add_argument('url', help='The TikTok URL to process')
    parser.add_argument('--server', default='http://localhost:8080', 
                        help='The API server URL (default: http://localhost:8080)')
    
    args = parser.parse_args()
    
    # Run the test
    test_process_tiktok(args.url, args.server)