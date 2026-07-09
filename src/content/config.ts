import { defineCollection, z } from "astro:content";

const postsCollection = defineCollection({
	schema: z.object({
		title: z.string(),
		published: z.date(),
		updated: z.date().optional(),
		draft: z.boolean().optional().default(false),
		description: z.string().optional().default(""),
		image: z.string().optional().default(""),
		tags: z.array(z.string()).optional().default([]),
		category: z.string().optional().nullable().default(""),
		lang: z.string().optional().default(""),

		/* For internal use */
		prevTitle: z.string().default(""),
		prevSlug: z.string().default(""),
		nextTitle: z.string().default(""),
		nextSlug: z.string().default(""),
	}),
});
const specCollection = defineCollection({
	schema: z.object({}),
});
// 项目展示集合：每个 Markdown 文件是一个项目，整卡指向外链
const projectsCollection = defineCollection({
	schema: z.object({
		title: z.string(),
		description: z.string().default(""),
		// 项目封面图，相对 /src 目录；以 / 开头则相对 /public
		image: z.string().default(""),
		// 项目链接（点击卡片跳转）
		url: z.string().url(),
		// 是否为内嵌项目（同域子路径，同窗口跳转，不显示外链图标）
		embedded: z.boolean().default(false),
		// 项目状态：ongoing / completed / archived
		status: z.enum(["ongoing", "completed", "archived"]).default("ongoing"),
		// 技术栈/标签
		tags: z.array(z.string()).default([]),
		// 排序权重，数字越小越靠前
		order: z.number().default(0),
		draft: z.boolean().default(false),
	}),
});
export const collections = {
	posts: postsCollection,
	spec: specCollection,
	projects: projectsCollection,
};
