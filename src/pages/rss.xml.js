import rss, { pagesGlobToRssItems } from '@astrojs/rss';

export async function GET(context) {
    return rss({
        title: 'WAHSUN Blog',
        description: 'WAHSUN 的个人博客',
        site: 'https://blog.wahsun.org',
        items: await pagesGlobToRssItems(import.meta.glob('./posts/*.md')),
        customData: `<language>zh-cn</language>`,
    });
}
