"""
Script to set a user as admin. Run: python set_admin.py <email>
Example: python set_admin.py admin@example.com
"""
import os
import sys
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'bubblesheet_backend.settings')
django.setup()

from users.models import User

if len(sys.argv) < 2:
    print("Usage: python set_admin.py <email>")
    sys.exit(1)

email = sys.argv[1]
try:
    user = User.objects.get(email=email)
    user.is_admin = True
    user.save()
    print(f"User {user.username} ({email}) is now admin.")
except User.DoesNotExist:
    print(f"User with email {email} not found.")
    sys.exit(1)
