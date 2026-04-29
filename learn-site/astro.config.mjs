import { defineConfig } from "astro/config";
import starlight from "@astrojs/starlight";

export default defineConfig({
  site: "https://regents.sh",
  output: "static",
  integrations: [
    starlight({
      title: "Regents Corpus",
      logo: {
        src: "../priv/static/images/regents-logo.png",
        alt: "Regents"
      },
      customCss: ["./src/styles/regents.css"],
      social: [
        { icon: "x.com", label: "Regents on X", href: "https://x.com/regents_sh" },
        { icon: "github", label: "Regents GitHub", href: "https://github.com/orgs/regents-ai/repositories" }
      ],
      sidebar: [
        {
          label: "Learn",
          autogenerate: { directory: "learn" }
        },
        {
          label: "Glossary",
          autogenerate: { directory: "glossary" }
        },
        {
          label: "Source Cards",
          autogenerate: { directory: "source" }
        },
        {
          label: "Updates",
          autogenerate: { directory: "updates" }
        }
      ]
    })
  ]
});
