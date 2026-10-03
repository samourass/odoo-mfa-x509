# -*- coding: utf-8 -*-
from datetime import timedelta

from odoo import fields
from odoo.tests.common import TransactionCase, tagged


@tagged('post_install', '-at_install')
class TestCertificate(TransactionCase):

    def setUp(self):
        super().setUp()
        Users = self.env['res.users']
        self.user_a = Users.create({'name': 'User A', 'login': 'a@example.test'})
        self.user_b = Users.create({'name': 'User B', 'login': 'b@example.test'})
        self.cert = self.env['mfa.user.certificate'].create({
            'name': 'A certificate',
            'user_id': self.user_a.id,
            'serial_number': '00ab12',
            'valid_until': fields.Datetime.now() + timedelta(days=30),
        })
        self.Cert = self.env['mfa.user.certificate']

    def test_serial_is_normalized(self):
        self.assertEqual(self.cert.serial_number, 'AB12')

    def test_unknown_certificate(self):
        ok, reason, _ = self.Cert.check_access_for('FFFF')
        self.assertFalse(ok)
        self.assertEqual(reason, 'Certificate is not registered in Odoo')

    def test_active_certificate_for_owner(self):
        ok, _reason, _ = self.Cert.check_access_for('AB12', self.user_a.id)
        self.assertTrue(ok)

    def test_wrong_user(self):
        ok, reason, _ = self.Cert.check_access_for('AB12', self.user_b.id)
        self.assertFalse(ok)
        self.assertEqual(reason, 'Certificate does not belong to this Odoo user')

    def test_suspended_and_revoked(self):
        self.cert.action_suspend()
        self.assertEqual(self.Cert.check_access_for('AB12')[1], 'Certificate status is suspended')
        self.cert.action_revoke()
        self.assertEqual(self.Cert.check_access_for('AB12')[1], 'Certificate status is revoked')

    def test_expired(self):
        self.cert.valid_until = fields.Datetime.now() - timedelta(days=1)
        ok, reason, _ = self.Cert.check_access_for('AB12')
        self.assertFalse(ok)
        self.assertEqual(reason, 'Certificate has expired')
