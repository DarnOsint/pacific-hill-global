/**
 * Brand mark and lockup.
 *
 * The mark is a summit over a swell: Pacific Hill over the Pacific. It carries
 * the same geometry as `src/app/icon.svg` and `src/app/favicon.ico`, so the
 * header, the favicon and the installed PWA icon are one drawing.
 *
 * The mark paints its own navy field, which is what lets a single component sit
 * unchanged on the light header and the dark footer.
 */

export function LogoMark({
  className = "",
  title = "Pacific Hill Global",
}: {
  className?: string;
  /** Pass `null` for a purely decorative mark inside an already-labelled link. */
  title?: string | null;
}) {
  return (
    <svg
      viewBox="0 0 512 512"
      className={className}
      role={title ? "img" : "presentation"}
      aria-label={title ?? undefined}
      aria-hidden={title ? undefined : true}
      focusable="false"
    >
      <defs>
        <linearGradient id="phg-mark-field" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#0f2033" />
          <stop offset="1" stopColor="#050d18" />
        </linearGradient>
        <linearGradient id="phg-mark-bronze" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#ebdbb8" />
          <stop offset="0.45" stopColor="#d0a054" />
          <stop offset="1" stopColor="#a26a2a" />
        </linearGradient>
      </defs>

      <rect width="512" height="512" rx="112" fill="url(#phg-mark-field)" />
      <rect
        x="14"
        y="14"
        width="484"
        height="484"
        rx="100"
        fill="none"
        stroke="#d0a054"
        strokeOpacity="0.22"
        strokeWidth="3"
      />

      <path d="M104 336 L236 132 L300 220 L344 154 L408 336 Z" fill="url(#phg-mark-bronze)" />
      <path
        d="M96 404 C150 372 202 432 256 404 C310 376 362 428 416 404"
        fill="none"
        stroke="#d0a054"
        strokeWidth="30"
        strokeLinecap="round"
      />
    </svg>
  );
}

/** Mark plus wordmark, used in the header and the footer. */
export function LogoLockup({
  className = "",
  markClassName = "h-9 w-9",
  tone = "dark",
}: {
  className?: string;
  markClassName?: string;
  /** `dark` for light surfaces, `light` for the dark footer. */
  tone?: "dark" | "light";
}) {
  return (
    <span className={`flex items-center gap-2.5 ${className}`}>
      <LogoMark className={`${markClassName} shrink-0 rounded-[7px]`} title={null} />
      <span className="flex items-baseline gap-1.5 leading-none">
        <span
          className={`font-display text-[1.0625rem] tracking-[-0.01em] ${
            tone === "dark" ? "text-ink-900" : "text-canvas"
          }`}
        >
          Pacific Hill
        </span>
        <span
          className={`text-[0.6875rem] font-semibold uppercase tracking-[0.18em] ${
            tone === "dark" ? "text-ink-500" : "text-bronze-300"
          }`}
        >
          Global
        </span>
      </span>
    </span>
  );
}
