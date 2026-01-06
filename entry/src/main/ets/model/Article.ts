export interface Article {
  id: number;
  title: string;
  desc: string;
  author: string;
  cid: number; // 分类id
  link?: string; // 原文链接，可选
  content: string; //正文
}
