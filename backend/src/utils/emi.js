/**
 * Loan maths. Interest is charged on a reducing balance, monthly.
 */

const round2 = (n) => Math.round(n * 100) / 100;

/** Monthly EMI for principal P, annual rate (percent) R, tenure N months. */
function calcEmi(principal, annualRatePct, months) {
  const P = Number(principal);
  const n = Number(months);
  const r = Number(annualRatePct) / 12 / 100;
  if (!P || !n) return 0;
  if (r === 0) return Math.ceil(P / n);
  const emi = (P * r * Math.pow(1 + r, n)) / (Math.pow(1 + r, n) - 1);
  return Math.ceil(emi);
}

function calcProcessingFee(amount, settings) {
  const pct = Number(settings.processingFeePercent || 0);
  const gstPct = Number(settings.gstPercent || 0);
  const base = Math.max(Number(settings.minProcessingFee || 0), (amount * pct) / 100);
  const gst = (base * gstPct) / 100;
  return { fee: Math.round(base), gst: Math.round(gst), total: Math.round(base + gst) };
}

/** Full quote for a given amount & tenure. */
function buildQuote(amount, months, settings) {
  const rate = Number(settings.interestRate);
  const emi = calcEmi(amount, rate, months);
  const totalPayable = emi * months;
  const pf = calcProcessingFee(amount, settings);
  return {
    amount: Number(amount),
    tenureMonths: Number(months),
    interestRate: rate,
    emi,
    totalPayable,
    totalInterest: totalPayable - Number(amount),
    processingFee: pf.fee,
    gstOnFee: pf.gst,
    totalFee: pf.total,
    disbursalAmount: Number(amount) - pf.total,
  };
}

/** Repayment schedule starting one month after `startDate`. */
function buildSchedule(amount, annualRatePct, months, startDate = new Date()) {
  const r = Number(annualRatePct) / 12 / 100;
  const emi = calcEmi(amount, annualRatePct, months);
  let balance = Number(amount);
  const rows = [];
  for (let i = 1; i <= months; i++) {
    const interest = round2(balance * r);
    let principal = round2(emi - interest);
    let amountDue = emi;
    if (i === months) {
      principal = round2(balance);
      amountDue = Math.ceil(principal + interest);
    }
    balance = round2(balance - principal);
    const due = new Date(startDate);
    due.setMonth(due.getMonth() + i);
    rows.push({
      installmentNo: i,
      dueDate: due,
      amount: amountDue,
      principal,
      interest,
      balanceAfter: Math.max(0, balance),
      status: 'pending',
    });
  }
  return rows;
}

/** Eligible loan range from monthly income. */
function eligibleRange(monthlyIncome, settings) {
  const income = Number(monthlyIncome) || 0;
  const step = Number(settings.amountStep || 1000);
  const raw = income * Number(settings.incomeMultiplier || 0.5);
  const max = Math.min(Number(settings.maxLoanAmount), Math.floor(raw / step) * step);
  return { min: Number(settings.minLoanAmount), max, step };
}

module.exports = { calcEmi, calcProcessingFee, buildQuote, buildSchedule, eligibleRange };
