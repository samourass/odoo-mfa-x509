# -*- coding: utf-8 -*-
from odoo import api, fields, models

STATES = [
    ('active', 'Active'),
    ('suspended', 'Suspended'),
    ('revoked', 'Revoked'),
]


def normalize_serial(serial):
    """Normalise un numéro de série pour la comparaison.

    Nginx ($ssl_client_serial) fournit le numéro de série en hexadécimal
    majuscule, sans zéros de tête. On applique la même forme à la saisie.
    """
    value = (serial or '').strip().replace(':', '').upper().lstrip('0')
    return value or '0'


class MfaUserCertificate(models.Model):
    _name = 'mfa.user.certificate'          # table : mfa_user_certificate
    _description = 'X.509 client certificate bound to an Odoo user'
    _order = 'name'

    name = fields.Char('Certificate Name', required=True)
    user_id = fields.Many2one('res.users', 'Odoo User', required=True,
                              ondelete='cascade', index=True)
    state = fields.Selection(STATES, 'Status', default='active',
                             required=True, index=True)
    serial_number = fields.Char('Serial Number', required=True, index=True)
    fingerprint_sha256 = fields.Char('SHA-256 Fingerprint')
    subject_dn = fields.Char('Subject DN')
    issuer_dn = fields.Char('Issuer DN')
    valid_from = fields.Datetime('Valid From')
    valid_until = fields.Datetime('Valid Until')

    _sql_constraints = [
        ('serial_number_unique', 'unique(serial_number)',
         'This serial number is already registered.'),
    ]

    # ------------------------------------------------------------------
    # Normalisation du numéro de série
    # ------------------------------------------------------------------
    @api.model_create_multi
    def create(self, vals_list):
        for vals in vals_list:
            if vals.get('serial_number'):
                vals['serial_number'] = normalize_serial(vals['serial_number'])
        return super().create(vals_list)

    def write(self, vals):
        if vals.get('serial_number'):
            vals['serial_number'] = normalize_serial(vals['serial_number'])
        return super().write(vals)

    # ------------------------------------------------------------------
    # Actions de l'interface
    # ------------------------------------------------------------------
    def action_activate(self):
        self.write({'state': 'active'})

    def action_suspend(self):
        self.write({'state': 'suspended'})

    def action_revoke(self):
        self.write({'state': 'revoked'})

    # ------------------------------------------------------------------
    # Logique de contrôle (appelée par les contrôleurs)
    # ------------------------------------------------------------------
    @api.model
    def check_access_for(self, serial, user_id=None):
        """Décide si un certificat est autorisé.

        Ordre des contrôles :
          1. numéro de série enregistré ;
          2. état « active » ;
          3. date de fin non dépassée ;
          4. propriétaire = utilisateur du login (si user_id est fourni).

        Retourne (ok, raison, enregistrement).
        """
        cert = self.sudo().search(
            [('serial_number', '=', normalize_serial(serial))], limit=1)
        if not cert:
            return False, 'Certificate is not registered in Odoo', cert
        if cert.state != 'active':
            return False, 'Certificate status is %s' % cert.state, cert
        if cert.valid_until and cert.valid_until < fields.Datetime.now():
            return False, 'Certificate has expired', cert
        if user_id and cert.user_id.id != user_id:
            return False, 'Certificate does not belong to this Odoo user', cert
        return True, 'OK', cert

    @api.model
    def create_from_pem(self, pem, user, name=None):
        """Crée un enregistrement depuis un certificat PEM (utilisé par
        deploy/50-register-cert.sh via « odoo shell »)."""
        from cryptography import x509
        from cryptography.hazmat.primitives import hashes
        from cryptography.x509.oid import NameOID

        def dn(name):
            # Même présentation que Nginx : « emailAddress=... » au lieu de l'OID.
            try:
                return name.rfc4514_string({NameOID.EMAIL_ADDRESS: 'emailAddress'})
            except TypeError:
                return name.rfc4514_string()

        data = pem.encode() if isinstance(pem, str) else pem
        cert = x509.load_pem_x509_certificate(data)
        not_before = getattr(cert, 'not_valid_before_utc', None) or cert.not_valid_before
        not_after = getattr(cert, 'not_valid_after_utc', None) or cert.not_valid_after
        fingerprint = ':'.join('%02X' % b for b in cert.fingerprint(hashes.SHA256()))
        return self.create({
            'name': name or dn(cert.subject),
            'user_id': user.id,
            'serial_number': format(cert.serial_number, 'X'),
            'fingerprint_sha256': fingerprint,
            'subject_dn': dn(cert.subject),
            'issuer_dn': dn(cert.issuer),
            'valid_from': not_before.replace(tzinfo=None),
            'valid_until': not_after.replace(tzinfo=None),
        })
