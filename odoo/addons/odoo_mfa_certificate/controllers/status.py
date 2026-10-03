# -*- coding: utf-8 -*-
"""Point de diagnostic : GET /mfa/certificate/status."""
import json

from odoo import http
from odoo.http import request
from odoo.addons.web.controllers.utils import ensure_db

from .helpers import client_identity, has_valid_mtls


class MfaCertificateStatus(http.Controller):

    @http.route('/mfa/certificate/status', type='http', auth='public',
                csrf=False, methods=['GET'])
    def certificate_status(self, **kw):
        ensure_db()
        identity = client_identity()
        payload = {
            'mtls': has_valid_mtls(identity),
            'verify': identity['verify'] or 'NONE',
            'subject': identity['subject'],
            'issuer': identity['issuer'],
            'serial': identity['serial'],
        }
        if payload['mtls']:
            # Si l'utilisateur est déjà connecté, on contrôle aussi le propriétaire.
            uid = request.session.uid or None
            ok, reason, _cert = request.env['mfa.user.certificate'].sudo() \
                .check_access_for(identity['serial'], uid)
            payload['authorized'] = ok
            if not ok:
                payload['reason'] = reason
        return request.make_response(
            json.dumps(payload),
            headers=[('Content-Type', 'application/json')])
