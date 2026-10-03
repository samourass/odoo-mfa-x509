# -*- coding: utf-8 -*-
"""Contrôle du certificat à la connexion (POST /web/login)."""
import logging

from markupsafe import escape

from odoo import http
from odoo.http import request
from odoo.addons.web.controllers.home import Home
from odoo.addons.web.controllers.utils import ensure_db

from .helpers import client_identity, has_valid_mtls

_logger = logging.getLogger(__name__)


class HomeMfa(Home):

    @http.route()
    def web_login(self, redirect=None, **kw):
        if request.httprequest.method == 'POST':
            ensure_db()
            login = request.params.get('login', '')
            identity = client_identity()
            serial = identity['serial']

            if not has_valid_mtls(identity):
                return self._deny(login, serial, 'Client certificate required')

            user = request.env['res.users'].sudo().search(
                [('login', '=', login)], limit=1)
            ok, reason, _cert = request.env['mfa.user.certificate'].sudo() \
                .check_access_for(serial, user.id if user else None)
            if not ok:
                return self._deny(login, serial, reason)

            _logger.info('X509 MFA certificate accepted for login=%s serial=%s',
                         login, serial)
        # Le mot de passe (puis le TOTP) sont contrôlés par Odoo.
        return super().web_login(redirect=redirect, **kw)

    @staticmethod
    def _deny(login, serial, reason):
        _logger.warning('X509 MFA denied for login=%s serial=%s reason=%s',
                        login, serial, reason)
        body = 'MFA authentication failed: %s' % escape(reason)
        response = request.make_response(
            body, headers=[('Content-Type', 'text/html; charset=utf-8')])
        response.status_code = 403
        return response
