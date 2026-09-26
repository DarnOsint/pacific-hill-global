"use client";

import * as React from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { Check, ChevronDown, CircleAlert, Info, Loader2, X } from "lucide-react";

import { cn } from "@/lib/utils";

/* =============================================================================
 * Badge
 * ========================================================================== */

const badgeVariants = cva("badge", {
  variants: {
    tone: {
      neutral: "badge-neutral",
      positive: "badge-positive",
      caution: "badge-caution",
      critical: "badge-critical",
      info: "badge-info",
      bronze: "badge-bronze",
    },
  },
  defaultVariants: { tone: "neutral" },
});

export function Badge({
  className,
  tone,
  dot = false,
  children,
  ...props
}: React.ComponentProps<"span"> &
  VariantProps<typeof badgeVariants> & { dot?: boolean }) {
  return (
    <span className={cn(badgeVariants({ tone }), className)} {...props}>
      {dot && (
        <span
          className="size-1.5 rounded-full bg-current opacity-70"
          aria-hidden
        />
      )}
      {children}
    </span>
  );
}

/* =============================================================================
 * Card
 * ========================================================================== */

export function Card({
  className,
  interactive = false,
  ...props
}: React.ComponentProps<"div"> & { interactive?: boolean }) {
  return (
    <div
      className={cn(
        "surface-card",
        interactive &&
          "transition-colors duration-200 hover:border-hairline-strong hover:bg-surface-muted",
        className,
      )}
      {...props}
    />
  );
}

export function CardHeader({
  className,
  title,
  description,
  action,
  ...props
}: React.ComponentProps<"div"> & {
  title?: React.ReactNode;
  description?: React.ReactNode;
  action?: React.ReactNode;
}) {
  return (
    <div
      className={cn(
        "flex items-start justify-between gap-4 border-b border-hairline px-5 py-4",
        className,
      )}
      {...props}
    >
      {(title || description) && (
        <div className="min-w-0">
          {title && (
            <h3 className="text-sm font-semibold text-ink-900">{title}</h3>
          )}
          {description && (
            <p className="mt-0.5 text-xs text-ink-500">{description}</p>
          )}
        </div>
      )}
      {action}
    </div>
  );
}

export function CardBody({ className, ...props }: React.ComponentProps<"div">) {
  return <div className={cn("px-5 py-4", className)} {...props} />;
}

export function CardFooter({ className, ...props }: React.ComponentProps<"div">) {
  return (
    <div
      className={cn(
        "flex items-center justify-between gap-3 border-t border-hairline bg-surface-muted px-5 py-3",
        className,
      )}
      {...props}
    />
  );
}

/* =============================================================================
 * Form field wrapper
 * ========================================================================== */

export function Field({
  label,
  htmlFor,
  hint,
  error,
  required,
  className,
  children,
}: {
  label?: React.ReactNode;
  htmlFor?: string;
  hint?: React.ReactNode;
  error?: string | null;
  required?: boolean;
  className?: string;
  children: React.ReactNode;
}) {
  return (
    <div className={cn("min-w-0", className)}>
      {label && (
        <label className="field-label" htmlFor={htmlFor}>
          {label}
          {required && <span className="ml-0.5 text-critical">*</span>}
        </label>
      )}
      {children}
      {error ? (
        <p className="field-error" role="alert">
          {error}
        </p>
      ) : hint ? (
        <p className="field-hint">{hint}</p>
      ) : null}
    </div>
  );
}

/* =============================================================================
 * Input / Textarea / Select
 * ========================================================================== */

export const Input = React.forwardRef<
  HTMLInputElement,
  React.ComponentProps<"input"> & { invalid?: boolean }
>(function Input({ className, invalid, ...props }, ref) {
  return (
    <input
      ref={ref}
      className={cn("field-input", className)}
      aria-invalid={invalid || undefined}
      {...props}
    />
  );
});

export const Textarea = React.forwardRef<
  HTMLTextAreaElement,
  React.ComponentProps<"textarea"> & { invalid?: boolean }
>(function Textarea({ className, invalid, ...props }, ref) {
  return (
    <textarea
      ref={ref}
      className={cn("field-input", className)}
      aria-invalid={invalid || undefined}
      {...props}
    />
  );
});

export const Select = React.forwardRef<
  HTMLSelectElement,
  React.ComponentProps<"select"> & { invalid?: boolean }
>(function Select({ className, invalid, children, ...props }, ref) {
  return (
    <select
      ref={ref}
      className={cn("field-input", className)}
      aria-invalid={invalid || undefined}
      {...props}
    >
      {children}
    </select>
  );
});

export function Checkbox({
  label,
  description,
  className,
  ...props
}: Omit<React.ComponentProps<"input">, "type"> & {
  label?: React.ReactNode;
  description?: React.ReactNode;
}) {
  return (
    <label className={cn("flex cursor-pointer items-start gap-2.5", className)}>
      <input
        type="checkbox"
        className="mt-0.5 size-4 shrink-0 rounded-xs border-hairline-strong text-ink-900 accent-ink-900"
        {...props}
      />
      {(label || description) && (
        <span className="min-w-0">
          {label && (
            <span className="block text-sm text-ink-800">{label}</span>
          )}
          {description && (
            <span className="mt-0.5 block text-xs text-ink-500">
              {description}
            </span>
          )}
        </span>
      )}
    </label>
  );
}

/* =============================================================================
 * Accordion (used on sector pages and detail panels)
 * ========================================================================== */

const accordionItemVariants = cva("last:border-b-0", {
  variants: {
    flush: { true: "border-b-0", false: "border-b border-hairline" },
  },
  defaultVariants: { flush: false },
});

export function AccordionItem({
  className,
  flush = false,
  ...props
}: React.ComponentProps<"details"> & { flush?: boolean }) {
  return (
    <details
      className={cn("group", accordionItemVariants({ flush }), className)}
      {...props}
    />
  );
}

export function AccordionTrigger({ className, ...props }: React.ComponentProps<"summary">) {
  return (
    <summary
      className={cn(
        "flex cursor-pointer list-none items-center justify-between gap-4 py-4 text-sm font-medium text-ink-900 marker:hidden",
        "[&::-webkit-details-marker]:hidden",
        className,
      )}
      {...props}
    />
  );
}

export function AccordionContent({ className, ...props }: React.ComponentProps<"div">) {
  return (
    <div
      className={cn("pb-5 text-sm leading-relaxed text-ink-600", className)}
      {...props}
    />
  );
}

/* =============================================================================
 * States: loading, empty, error
 * ========================================================================== */

export function Spinner({ className, label }: { className?: string; label?: string }) {
  return (
    <span className="inline-flex items-center gap-2">
      <Loader2 className={cn("size-4 animate-spin text-ink-500", className)} aria-hidden />
      {label && <span className="text-sm text-ink-600">{label}</span>}
    </span>
  );
}

export function Skeleton({ className, ...props }: React.ComponentProps<"div">) {
  return <div className={cn("skeleton", className)} aria-hidden {...props} />;
}

export function TableSkeleton({
  rows = 8,
  columns = 5,
}: {
  rows?: number;
  columns?: number;
}) {
  return (
    <div className="divide-y divide-hairline" aria-busy>
      {Array.from({ length: rows }).map((_, r) => (
        <div key={r} className="flex items-center gap-4 px-4 py-3">
          {Array.from({ length: columns }).map((_, c) => (
            <Skeleton
              key={c}
              className="h-3.5"
              style={{ width: `${[28, 16, 12, 20, 14, 10][c % 6]}%` }}
            />
          ))}
        </div>
      ))}
    </div>
  );
}

export function EmptyState({
  icon: Icon,
  title,
  description,
  action,
  className,
}: {
  icon?: React.ComponentType<{ className?: string }>;
  title: string;
  description?: React.ReactNode;
  action?: React.ReactNode;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "flex flex-col items-center justify-center px-6 py-14 text-center",
        className,
      )}
    >
      {Icon && (
        <div className="mb-4 flex size-11 items-center justify-center rounded-full bg-sand-100">
          <Icon className="size-5 text-ink-400" />
        </div>
      )}
      <p className="font-display text-lg text-ink-900">{title}</p>
      {description && (
        <p className="mt-1.5 max-w-sm text-sm leading-relaxed text-ink-500">
          {description}
        </p>
      )}
      {action && <div className="mt-5">{action}</div>}
    </div>
  );
}

export function ErrorState({
  title = "Something went wrong",
  description,
  reference,
  action,
  className,
}: {
  title?: string;
  description?: React.ReactNode;
  reference?: string;
  action?: React.ReactNode;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "flex flex-col items-center justify-center px-6 py-14 text-center",
        className,
      )}
      role="alert"
    >
      <div className="mb-4 flex size-11 items-center justify-center rounded-full bg-critical-soft">
        <CircleAlert className="size-5 text-critical" />
      </div>
      <p className="font-display text-lg text-ink-900">{title}</p>
      {description && (
        <p className="mt-1.5 max-w-md text-sm leading-relaxed text-ink-500">
          {description}
        </p>
      )}
      {reference && (
        <p className="mt-3 font-mono text-2xs text-ink-400">
          Reference: {reference}
        </p>
      )}
      {action && <div className="mt-5">{action}</div>}
    </div>
  );
}

/* =============================================================================
 * Inline alert
 * ========================================================================== */

const alertTone = {
  info: { wrap: "bg-info-soft text-info", Icon: Info },
  success: { wrap: "bg-positive-soft text-positive", Icon: Check },
  warning: { wrap: "bg-caution-soft text-caution", Icon: CircleAlert },
  error: { wrap: "bg-critical-soft text-critical", Icon: X },
} as const;

export function Alert({
  tone = "info",
  title,
  children,
  className,
  onDismiss,
}: {
  tone?: keyof typeof alertTone;
  title?: React.ReactNode;
  children?: React.ReactNode;
  className?: string;
  onDismiss?: () => void;
}) {
  const { wrap, Icon } = alertTone[tone];
  return (
    <div
      className={cn(
        "flex items-start gap-2.5 rounded-md px-3.5 py-3 text-sm",
        wrap,
        className,
      )}
      role={tone === "error" ? "alert" : "status"}
    >
      <Icon className="mt-0.5 size-4 shrink-0" aria-hidden />
      <div className="min-w-0 flex-1">
        {title && <p className="font-semibold">{title}</p>}
        {children && <div className="leading-relaxed opacity-90">{children}</div>}
      </div>
      {onDismiss && (
        <button
          type="button"
          onClick={onDismiss}
          className="shrink-0 opacity-60 transition-opacity hover:opacity-100"
          aria-label="Dismiss"
        >
          <X className="size-4" />
        </button>
      )}
    </div>
  );
}

/* =============================================================================
 * Selectable list (used for pickers: units, staff, suppliers)
 * ========================================================================== */

export function OptionList({
  options,
  value,
  onChange,
  className,
  emptyLabel = "No options available",
}: {
  options: { value: string; label: string; description?: string; icon?: React.ReactNode }[];
  value?: string;
  onChange: (value: string) => void;
  className?: string;
  emptyLabel?: string;
}) {
  if (options.length === 0) {
    return <p className="px-3 py-6 text-center text-sm text-ink-400">{emptyLabel}</p>;
  }
  return (
    <div className={cn("py-1", className)} role="listbox">
      {options.map((option) => (
        <button
          key={option.value}
          type="button"
          role="option"
          aria-selected={value === option.value}
          onClick={() => onChange(option.value)}
          className={cn(
            "flex w-full items-center gap-3 px-3 py-2.5 text-left transition-colors",
            value === option.value
              ? "bg-ink-900 text-canvas"
              : "text-ink-800 hover:bg-sand-100",
          )}
        >
          {option.icon}
          <span className="min-w-0 flex-1">
            <span className="block truncate text-sm font-medium">
              {option.label}
            </span>
            {option.description && (
              <span
                className={cn(
                  "block truncate text-xs",
                  value === option.value ? "text-ink-300" : "text-ink-500",
                )}
              >
                {option.description}
              </span>
            )}
          </span>
          {value === option.value && <Check className="size-4 shrink-0" />}
        </button>
      ))}
    </div>
  );
}

/* =============================================================================
 * Tabs (CSS-only, no client JS needed for simple cases)
 * ========================================================================== */

export function Tabs({
  tabs,
  active,
  className,
}: {
  tabs: { id: string; label: string; count?: number }[];
  active: string;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "no-scrollbar flex gap-1 overflow-x-auto border-b border-hairline",
        className,
      )}
      role="tablist"
    >
      {tabs.map((tab) => (
        <a
          key={tab.id}
          href={`#${tab.id}`}
          role="tab"
          aria-selected={active === tab.id}
          className={cn(
            "-mb-px flex shrink-0 items-center gap-2 border-b-2 px-3.5 py-2.5 text-sm font-medium transition-colors",
            active === tab.id
              ? "border-ink-900 text-ink-900"
              : "border-transparent text-ink-500 hover:text-ink-800",
          )}
        >
          {tab.label}
          {tab.count !== undefined && (
            <span className="badge badge-neutral tabular">{tab.count}</span>
          )}
        </a>
      ))}
    </div>
  );
}

/* =============================================================================
 * Description list
 * ========================================================================== */

export function DescriptionList({
  items,
  columns = 2,
  className,
}: {
  items: { label: React.ReactNode; value: React.ReactNode; span?: boolean }[];
  columns?: 1 | 2 | 3;
  className?: string;
}) {
  const cols = {
    1: "sm:grid-cols-1",
    2: "sm:grid-cols-2",
    3: "sm:grid-cols-2 lg:grid-cols-3",
  }[columns];

  return (
    <dl className={cn("grid grid-cols-1 gap-x-6 gap-y-4", cols, className)}>
      {items.map((item, i) => (
        <div key={i} className={cn(item.span && "sm:col-span-full")}>
          <dt className="text-2xs font-semibold tracking-[0.08em] text-ink-400 uppercase">
            {item.label}
          </dt>
          <dd className="mt-1 text-sm text-ink-800">{item.value ?? "—"}</dd>
        </div>
      ))}
    </dl>
  );
}

/* =============================================================================
 * Progress
 * ========================================================================== */

export function Progress({
  value,
  max = 100,
  tone = "ink",
  label,
  className,
}: {
  value: number;
  max?: number;
  tone?: "ink" | "positive" | "caution" | "critical" | "bronze";
  label?: string;
  className?: string;
}) {
  const pct = Math.max(0, Math.min(100, (value / max) * 100));
  const bar = {
    ink: "bg-ink-800",
    positive: "bg-positive",
    caution: "bg-caution",
    critical: "bg-critical",
    bronze: "bg-bronze-500",
  }[tone];

  return (
    <div
      className={cn("flex items-center gap-2.5", className)}
      role="progressbar"
      aria-valuenow={Math.round(pct)}
      aria-valuemin={0}
      aria-valuemax={100}
      aria-label={label}
    >
      <div className="h-1.5 flex-1 overflow-hidden rounded-full bg-sand-200">
        <div
          className={cn("h-full rounded-full transition-[width] duration-500", bar)}
          style={{ width: `${pct}%` }}
        />
      </div>
      {label && <span className="tabular text-xs text-ink-500">{label}</span>}
    </div>
  );
}

/* =============================================================================
 * Divider with label
 * ========================================================================== */

export function LabelledDivider({
  children,
  className,
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div className={cn("flex items-center gap-3", className)}>
      <span className="h-px flex-1 bg-hairline" />
      <span className="text-2xs font-semibold tracking-[0.08em] text-ink-400 uppercase">
        {children}
      </span>
      <span className="h-px flex-1 bg-hairline" />
    </div>
  );
}

export { ChevronDown };
