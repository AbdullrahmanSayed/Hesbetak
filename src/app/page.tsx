import { APP_NAME } from "@/config/app";

export default function HomePage() {
  return (
    <main className="flex min-h-screen items-center justify-center px-4">
      <h1 className="text-4xl font-bold">{APP_NAME.ar}</h1>
    </main>
  );
}
