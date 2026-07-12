"use client";

export default function GlobalError({
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <html lang="en">
      <body className="min-h-full bg-[#06070a] text-white antialiased">
        <div className="mx-auto flex min-h-screen max-w-lg flex-col items-center justify-center px-6 py-24 text-center">
          <h1 className="text-[1.75rem] font-semibold tracking-tight">Something went wrong</h1>
          <p className="mt-3 text-[15px] leading-relaxed text-white/55">
            WeekFit encountered an unexpected error. Please try again.
          </p>
          <button
            type="button"
            onClick={reset}
            className="mt-8 min-h-[44px] rounded-full border border-white/12 bg-white/[0.06] px-5 text-[15px] font-semibold"
          >
            Try again
          </button>
        </div>
      </body>
    </html>
  );
}
