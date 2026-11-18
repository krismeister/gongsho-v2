import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  site: 'https://krismeister.github.io/gongsho-v2',
  base: '/gongsho-v2/',
  integrations: [
    starlight({
      title: 'Gongsho',
      sidebar: [
        { label: 'Install', slug: 'install' },
        { label: 'Skills', slug: 'skills' },
        {
          label: 'Agent docs',
          items: [
            { label: 'Start here', slug: 'ai' },
            { label: 'Runbook', slug: 'ai/runbook' },
          ],
        },
      ],
    }),
  ],
});
