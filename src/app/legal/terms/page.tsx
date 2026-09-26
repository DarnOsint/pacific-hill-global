import { CmsPage } from "@/components/marketing/cms-page";

export const revalidate = 60;

export default function Page() {
  return <CmsPage slug="legal/terms" />;
}
