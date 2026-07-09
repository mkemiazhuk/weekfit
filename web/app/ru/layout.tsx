import { LocaleConfigProvider } from "@/lib/locale-context";

export default function RuLayout({ children }: { children: React.ReactNode }) {
  return <LocaleConfigProvider locale="ru">{children}</LocaleConfigProvider>;
}
