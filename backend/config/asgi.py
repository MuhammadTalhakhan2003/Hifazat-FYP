"""
ASGI config for config project.

It exposes the ASGI callable as a module-level variable named ``application``.

For more information on this file, see
https://docs.djangoproject.com/en/stable/howto/deployment/asgi/
"""

import os

from channels.auth import AuthMiddlewareStack # If using Channels Auth
from channels.routing import ProtocolTypeRouter, URLRouter
from channels.security.websocket import AllowedHostsOriginValidator # If using WS security
from django.core.asgi import get_asgi_application

# IMPORTANT: Make sure this matches your settings file location
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')

# Import routing *after* settings are loaded (if your routing uses Django models/settings)
# Example: import api.routing # Replace with your actual Channels routing module if you have one

# Get the default Django ASGI application handler
django_asgi_app = get_asgi_application()

application = ProtocolTypeRouter({
    # Django's ASGI application to handle traditional HTTP requests
    "http": django_asgi_app,

    # WebSocket chat handler
    "websocket": AllowedHostsOriginValidator( # Wrap in validator if needed
        AuthMiddlewareStack( # Wrap in Auth if needed
            URLRouter(
                # Add your WebSocket URL patterns here if using Channels
                # Example: api.routing.websocket_urlpatterns
                [] # Placeholder: Add your app's routing here
            )
        )
    ),
})
