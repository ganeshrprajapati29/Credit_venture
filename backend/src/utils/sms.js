/**
 * OTP SMS sender. Configure in backend/.env when you are ready to send real SMS:
 *
 *   SMS_PROVIDER=msg91      MSG91_AUTHKEY=xxxx   MSG91_TEMPLATE_ID=xxxx
 *   SMS_PROVIDER=2factor    TWOFACTOR_API_KEY=xxxx  (TWOFACTOR_TEMPLATE=optional template name)
 *
 * Then switch "Login OTP mode" to "SMS" in Admin → App Settings → App.
 */

const provider = () => (process.env.SMS_PROVIDER || '').toLowerCase();

const isConfigured = () => {
  switch (provider()) {
    case 'msg91':
      return !!(process.env.MSG91_AUTHKEY && process.env.MSG91_TEMPLATE_ID);
    case '2factor':
      return !!process.env.TWOFACTOR_API_KEY;
    default:
      return false;
  }
};

async function sendOtpSms(mobile, otp) {
  switch (provider()) {
    case 'msg91': {
      const url = new URL('https://control.msg91.com/api/v5/otp');
      url.searchParams.set('template_id', process.env.MSG91_TEMPLATE_ID);
      url.searchParams.set('mobile', `91${mobile}`);
      url.searchParams.set('otp', otp);
      const r = await fetch(url, { method: 'POST', headers: { authkey: process.env.MSG91_AUTHKEY, 'Content-Type': 'application/json' }, body: '{}' });
      const j = await r.json().catch(() => ({}));
      if (!r.ok || j.type === 'error') throw new Error(`MSG91: ${j.message || r.status}`);
      return;
    }
    case '2factor': {
      const tpl = process.env.TWOFACTOR_TEMPLATE ? `/${encodeURIComponent(process.env.TWOFACTOR_TEMPLATE)}` : '';
      const r = await fetch(`https://2factor.in/API/V1/${process.env.TWOFACTOR_API_KEY}/SMS/+91${mobile}/${otp}${tpl}`);
      const j = await r.json().catch(() => ({}));
      if (!r.ok || j.Status !== 'Success') throw new Error(`2Factor: ${j.Details || r.status}`);
      return;
    }
    default:
      throw new Error('No SMS provider configured');
  }
}

module.exports = { sendOtpSms, isSmsConfigured: isConfigured };
