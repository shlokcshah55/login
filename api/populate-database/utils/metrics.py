"""
Metrics utilities for the TikTok processing API.
This module provides functions for tracking API requests and errors.
"""
import os
import logging
import time
from typing import Dict, Any, Optional
from datetime import datetime

# Try to import Google Cloud Monitoring libraries
try:
    from google.cloud import monitoring_v3
    from google.api import metric_pb2, resource_pb2
    CLOUD_MONITORING_AVAILABLE = True
except ImportError:
    CLOUD_MONITORING_AVAILABLE = False

# Configure logging
logger = logging.getLogger(__name__)

# Constants
PROJECT_ID = os.environ.get("GOOGLE_CLOUD_PROJECT")
SERVICE_NAME = os.environ.get("SERVICE_NAME", "tiktok-processing-api")
ENVIRONMENT = os.environ.get("ENVIRONMENT", "development")

# Initialize monitoring client
monitoring_client = None

def initialize_monitoring():
    """Initialize Google Cloud Monitoring client"""
    global monitoring_client, CLOUD_MONITORING_AVAILABLE
    
    if not CLOUD_MONITORING_AVAILABLE:
        logger.warning("Google Cloud Monitoring libraries not installed. Metrics will not be sent to Cloud Monitoring.")
        return False
    
    if monitoring_client:
        return True
    
    if not PROJECT_ID:
        logger.warning("GOOGLE_CLOUD_PROJECT environment variable not set. Metrics will not be sent to Cloud Monitoring.")
        CLOUD_MONITORING_AVAILABLE = False
        return False
    
    try:
        monitoring_client = monitoring_v3.MetricServiceClient()
        logger.info("Google Cloud Monitoring client initialized")
        return True
        
    except Exception as e:
        logger.error(f"Failed to initialize Google Cloud Monitoring client: {e}")
        CLOUD_MONITORING_AVAILABLE = False
        return False

# Initialize monitoring on module import
if os.environ.get("ENVIRONMENT") == "production":
    initialize_monitoring()

def track_api_request(endpoint: str, latency_ms: Optional[float] = None):
    """
    Track an API request for metrics purposes.
    
    Args:
        endpoint: The API endpoint being called
        latency_ms: Optional latency in milliseconds
    """
    # Log the request
    logger.info(f"API Request: {endpoint}" + (f", Latency: {latency_ms}ms" if latency_ms else ""))
    
    # If in development mode, just log and return
    if ENVIRONMENT != "production":
        return
    
    # If Cloud Monitoring is not available, just return
    if not CLOUD_MONITORING_AVAILABLE or not monitoring_client:
        return
        
    try:
        # Create a custom metric for API request
        metric_path = f"custom.googleapis.com/{SERVICE_NAME}/api/requests"
        
        # Create the time series
        series = monitoring_v3.TimeSeries()
        series.metric.type = metric_path
        series.metric.labels["endpoint"] = endpoint
        series.metric.labels["environment"] = ENVIRONMENT
        
        # Set the resource
        series.resource.type = "global"
        
        # Add data point (count = 1)
        point = series.points.add()
        point.value.int64_value = 1
        now = time.time()
        point.interval.end_time.seconds = int(now)
        point.interval.end_time.nanos = int((now - int(now)) * 10**9)
        
        # Write the time series
        project_name = f"projects/{PROJECT_ID}"
        monitoring_client.create_time_series(name=project_name, time_series=[series])
        
        # If latency is provided, also track that
        if latency_ms is not None:
            # Create latency metric
            latency_metric_path = f"custom.googleapis.com/{SERVICE_NAME}/api/latency"
            
            # Create the time series for latency
            latency_series = monitoring_v3.TimeSeries()
            latency_series.metric.type = latency_metric_path
            latency_series.metric.labels["endpoint"] = endpoint
            latency_series.metric.labels["environment"] = ENVIRONMENT
            
            # Set the resource
            latency_series.resource.type = "global"
            
            # Add data point with latency value
            latency_point = latency_series.points.add()
            latency_point.value.double_value = latency_ms
            latency_point.interval.end_time.seconds = int(now)
            latency_point.interval.end_time.nanos = int((now - int(now)) * 10**9)
            
            # Write the latency time series
            monitoring_client.create_time_series(name=project_name, time_series=[latency_series])
            
    except Exception as e:
        logger.error(f"Failed to track API request metric: {e}")

def track_error(error_type: str, error_message: str):
    """
    Track an error for metrics purposes.
    
    Args:
        error_type: Type of error (e.g., "validation_error", "auth_error")
        error_message: Error message or details
    """
    # Log the error
    logger.warning(f"Error tracked: {error_type} - {error_message}")
    
    # If in development mode, just log and return
    if ENVIRONMENT != "production":
        return
    
    # If Cloud Monitoring is not available, just return
    if not CLOUD_MONITORING_AVAILABLE or not monitoring_client:
        return
        
    try:
        # Create a custom metric for errors
        metric_path = f"custom.googleapis.com/{SERVICE_NAME}/errors"
        
        # Create the time series
        series = monitoring_v3.TimeSeries()
        series.metric.type = metric_path
        series.metric.labels["error_type"] = error_type
        series.metric.labels["environment"] = ENVIRONMENT
        
        # Set the resource
        series.resource.type = "global"
        
        # Add data point (count = 1)
        point = series.points.add()
        point.value.int64_value = 1
        now = time.time()
        point.interval.end_time.seconds = int(now)
        point.interval.end_time.nanos = int((now - int(now)) * 10**9)
        
        # Write the time series
        project_name = f"projects/{PROJECT_ID}"
        monitoring_client.create_time_series(name=project_name, time_series=[series])
            
    except Exception as e:
        logger.error(f"Failed to track error metric: {e}")