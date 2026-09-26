/**
 * Money.
 *
 * Rules:
 *   - Never use `number` for a monetary *calculation* you intend to persist.
 *     Values arrive from Postgres as `numeric` (supabase-js returns them as
 *     numbers when they fit, strings when they do not), so we normalise to
 *     `number` for display and arithmetic but ALWAYS round at the currency's
 *     minor unit before persisting.
 *   - Exchange rate semantics are fixed and used consistently everywhere,
 *     including in the SQL views: a record's `exchange_rate` means
 *     "1 unit of this record's currency = N units of base currency".
 *   - The base currency is read from company_settings, never hardcoded.
 */
import type { CurrencyRow } from "@/types/database";

export type MoneyInput = number | string | null | undefined;

export type Money = {
  amount: number;
  currency: string;
  baseAmount: number | null;
  baseCurrency: string | null;
  exchangeRate: number | null;
};

/* -------------------------------------------------------------------------- */
/* Normalisation                                                               */
/* -------------------------------------------------------------------------- */

export function toNumber(value: MoneyInput): number {
  if (value === null || value === undefined || value === "") return 0;
  const n = typeof value === "number" ? value : Number.parseFloat(value);
  return Number.isFinite(n) ? n : 0;
}

/** Round to a currency's minor unit. `2` → cents, `0` → whole units. */
export function roundToMinorUnit(amount: number, minorUnit = 2): number {
  const factor = 10 ** minorUnit;
  return Math.round((amount + Number.EPSILON) * factor) / factor;
}

/**
 * Build a monetary value.
 *
 * When the currency differs from the base and no rate is supplied, the rate
 * defaults to 1 and a warning is recorded — the service layer must supply a real
 * rate for a cross-currency record. Silently treating SSP as USD would corrupt
 * every report, so this is loud rather than convenient.
 */
export function toMoney(params: {
  amount: MoneyInput;
  currency: string;
  baseCurrency?: string;
  exchangeRate?: MoneyInput;
}): Money & { rateMissing: boolean } {
  const amount = roundToMinorUnit(toNumber(params.amount), 4);
  const currency = params.currency.toUpperCase();
  const baseCurrency = params.baseCurrency?.toUpperCase() ?? null;
  const suppliedRate = params.exchangeRate ?? null;

  if (!baseCurrency || currency === baseCurrency) {
    return {
      amount,
      currency,
      baseAmount: baseCurrency ? amount : null,
      baseCurrency,
      exchangeRate: 1,
      rateMissing: false,
    };
  }

  const exchangeRate =
    suppliedRate !== null ? toNumber(suppliedRate) || 1 : 1;

  return {
    amount,
    currency,
    baseAmount: roundToMinorUnit(amount * exchangeRate, 4),
    baseCurrency,
    exchangeRate,
    rateMissing: suppliedRate === null,
  };
}

/* -------------------------------------------------------------------------- */
/* Formatting                                                                  */
/* -------------------------------------------------------------------------- */

const CURRENCY_FORMATTERS = new Map<string, Intl.NumberFormat>();

function formatter(currency: string, locale: string, compact: boolean): Intl.NumberFormat {
  const key = `${currency}:${locale}:${compact}`;
  let f = CURRENCY_FORMATTERS.get(key);
  if (!f) {
    f = new Intl.NumberFormat(locale, {
      style: "currency",
      currency,
      notation: compact ? "compact" : "standard",
      maximumFractionDigits: compact ? 1 : 2,
    });
    CURRENCY_FORMATTERS.set(key, f);
  }
  return f;
}

/** `$1,234.50` */
export function formatMoney(
  amount: MoneyInput,
  currency = "USD",
  locale = "en-US",
): string {
  const value = toNumber(amount);
  try {
    return formatter(currency.toUpperCase(), locale, false).format(value);
  } catch {
    // Unknown currency code: fall back to a neutral numeric format rather than
    // throwing inside a render.
    return `${currency.toUpperCase()} ${value.toFixed(2)}`;
  }
}

/** `$1.2M` — for dashboard tiles and chart axes. */
export function formatMoneyCompact(
  amount: MoneyInput,
  currency = "USD",
  locale = "en-US",
): string {
  const value = toNumber(amount);
  try {
    return formatter(currency.toUpperCase(), locale, true).format(value);
  } catch {
    return `${currency.toUpperCase()} ${Intl.NumberFormat(locale, {
      notation: "compact",
      maximumFractionDigits: 1,
    }).format(value)}`;
  }
}

/** `1,234.50` — for table cells where the currency is in the column header. */
export function formatNumber(
  amount: MoneyInput,
  locale = "en-US",
  fractionDigits = 2,
): string {
  return new Intl.NumberFormat(locale, {
    minimumFractionDigits: fractionDigits,
    maximumFractionDigits: fractionDigits,
  }).format(toNumber(amount));
}

/** A value already expressed in base currency, labelled with the base code. */
export function formatBase(
  amount: MoneyInput,
  baseCurrency = "USD",
  locale = "en-US",
): string {
  return formatMoney(amount, baseCurrency, locale);
}

/* -------------------------------------------------------------------------- */
/* Currency metadata                                                           */
/* -------------------------------------------------------------------------- */

export function currencySymbol(currency: string, currencies: CurrencyRow[]): string {
  return currencies.find((c) => c.code === currency.toUpperCase())?.symbol ?? currency;
}

export function minorUnitFor(currency: string, currencies: CurrencyRow[]): number {
  return (
    currencies.find((c) => c.code === currency.toUpperCase())?.minor_unit ?? 2
  );
}

/* -------------------------------------------------------------------------- */
/* Percentage                                                                  */
/* -------------------------------------------------------------------------- */

export function formatPercent(value: MoneyInput, fractionDigits = 1): string {
  return `${toNumber(value).toFixed(fractionDigits)}%`;
}

/** `+12.4%` / `−8.1%` — signed, for deltas. */
export function formatDelta(value: MoneyInput, fractionDigits = 1): string {
  const n = toNumber(value);
  const sign = n > 0 ? "+" : n < 0 ? "\u2212" : "";
  return `${sign}${Math.abs(n).toFixed(fractionDigits)}%`;
}

export function deltaTone(value: MoneyInput): "positive" | "negative" | "neutral" {
  const n = toNumber(value);
  if (n > 0) return "positive";
  if (n < 0) return "negative";
  return "neutral";
}
