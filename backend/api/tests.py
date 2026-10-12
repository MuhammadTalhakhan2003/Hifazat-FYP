import re

from django.contrib.auth.models import User
from django.core import mail
from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from .models import PasswordResetCode


@override_settings(EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend')
class PasswordResetTests(TestCase):
    NEW_PASSWORD = 'Sunrise-Lahore-2026'

    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user('ali', 'ali@example.com', 'OldPassword-123')

    def request_code(self, email='ali@example.com'):
        return self.client.post('/api/auth/password-reset/', {'email': email}, format='json')

    def sent_code(self):
        return re.search(r'\b(\d{6})\b', mail.outbox[-1].body).group(1)

    def confirm(self, code, password=None):
        password = password or self.NEW_PASSWORD
        return self.client.post('/api/auth/password-reset/confirm/', {
            'email': 'ali@example.com', 'code': code,
            'new_password': password, 'new_password2': password,
        }, format='json')

    def test_full_flow_resets_password(self):
        self.assertEqual(self.request_code('ALI@example.com').status_code, 200)
        self.assertEqual(len(mail.outbox), 1)
        code = self.sent_code()

        verify = self.client.post('/api/auth/password-reset/verify/',
                                  {'email': 'ali@example.com', 'code': code}, format='json')
        self.assertEqual(verify.status_code, 200)

        self.assertEqual(self.confirm(code).status_code, 200)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password(self.NEW_PASSWORD))
        # A code works only once
        self.assertEqual(self.confirm(code).status_code, 400)

    def test_unknown_email_gets_same_response_and_no_mail(self):
        response = self.request_code('nobody@example.com')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(mail.outbox), 0)

    def test_wrong_code_is_limited_to_five_attempts(self):
        self.request_code()
        code = self.sent_code()
        wrong = '000000' if code != '000000' else '111111'
        for _ in range(5):
            self.assertEqual(self.confirm(wrong).status_code, 400)
        # Even the right code is now refused
        self.assertEqual(self.confirm(code).status_code, 400)

    def test_resend_cooldown_and_new_code_replaces_old(self):
        self.request_code()
        self.request_code()  # Within the cooldown: no second email
        self.assertEqual(len(mail.outbox), 1)
        old_code = self.sent_code()

        PasswordResetCode.objects.update(created_at=PasswordResetCode.objects.first().created_at.replace(year=2000))
        self.request_code()
        self.assertEqual(len(mail.outbox), 2)
        new_code = self.sent_code()
        if old_code != new_code:
            self.assertEqual(self.confirm(old_code).status_code, 400)
        self.assertEqual(self.confirm(new_code).status_code, 200)

    def test_weak_password_rejected(self):
        self.request_code()
        response = self.confirm(self.sent_code(), password='12345678')
        self.assertEqual(response.status_code, 400)
        self.assertIn('new_password', response.data)
