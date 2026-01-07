export interface Comment {
  id: string;
  articleId: number;
  userId: string;
  nickname: string;
  content: string;
  createdAt: number;
  parentId?: string;
  replyTo?: string;
}