from rest_framework import permissions


class IsAdmin(permissions.BasePermission):
    """Only allow admin users."""

    def has_permission(self, request, view):
        return (
            request.user
            and request.user.is_authenticated
            and getattr(request.user, "is_admin", False)
        )
