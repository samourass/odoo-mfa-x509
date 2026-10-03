# -*- coding: utf-8 -*-
{
    'name': 'MFA X.509 Certificate',
    'version': '18.0.1.0.0',
    'category': 'Extra Tools',
    'summary': 'Lie un certificat client X.509 (mTLS Nginx) à un compte Odoo et contrôle son état',
    'description': """
Facteur « certificat » pour l'authentification forte d'Odoo.

Nginx authentifie le certificat client (mTLS) et transmet son identité à Odoo.
Ce module vérifie ensuite que le certificat est enregistré, actif, valide et
qu'il appartient à l'utilisateur qui se connecte. Le mot de passe et le TOTP
restent gérés par Odoo (module auth_totp).
    """,
    'author': 'Samar Souid',
    'license': 'LGPL-3',
    'depends': ['base', 'web', 'auth_totp'],
    'data': [
        'security/ir.model.access.csv',
        'views/mfa_user_certificate_views.xml',
    ],
    'installable': True,
    'application': True,
}
