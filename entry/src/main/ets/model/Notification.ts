/*
 * Notification.ts - 通知数据模型接口
 * 
 * 功能说明：
 * - 定义通知数据的结构和类型
 * - 支持不同类型的通知（点赞、回复）
 * - 包含通知状态和关联信息
 * 
 * 通知类型说明：
 * - comment_like: 评论被点赞
 * - comment_reply: 收到评论回复
 * 
 * 数据字段说明：
 * - id: 通知唯一标识
 * - type: 通知类型
 * - articleId: 关联的文章ID
 * - articleTitle: 文章标题
 * - commentId: 关联的评论ID
 * - fromUserId: 触发通知的用户ID
 * - fromNickname: 触发通知的用户昵称
 * - content: 通知内容（可选）
 * - createdAt: 通知创建时间戳
 * - read: 是否已读状态
 */

/**
 * 通知类型定义
 * 表示不同类型的用户通知
 */
export type NotificationType = 'comment_like' | 'comment_reply';

/**
 * 通知项数据模型接口
 * 
 * 表示一条用户通知，包含通知内容和状态信息
 * 用于通知中心和个人消息功能
 */
export interface NotificationItem {
  /**
   * 通知唯一标识符
   * 用于区分不同通知，通常由后端生成
   */
  id: string;

  /**
   * 通知类型
   * 区分不同的通知场景
   * - comment_like: 评论被点赞
   * - comment_reply: 收到评论回复
   */
  type: NotificationType;

  /**
   * 关联的文章ID
   * 指向通知相关的文章
   * 用于跳转到对应文章页面
   */
  articleId: number;

  /**
   * 文章标题
   * 显示通知相关的文章标题
   * 便于用户识别通知来源
   */
  articleTitle: string;

  /**
   * 关联的评论ID
   * 指向通知相关的评论
   * 用于定位到具体评论位置
   */
  commentId: string;

  /**
   * 触发通知的用户ID
   * 表示哪个用户触发了此通知
   */
  fromUserId: string;

  /**
   * 触发通知的用户昵称
   * 显示触发通知的用户名称
   */
  fromNickname: string;

  /**
   * 通知内容
   * 可选字段，包含额外的通知信息
   * 如回复的具体内容等
   */
  content?: string;

  /**
   * 通知创建时间戳
   * 毫秒级时间戳，表示通知产生时间
   * 用于通知排序和时间显示
   */
  createdAt: number;

  /**
   * 是否已读状态
   * 标记用户是否已查看此通知
   * true: 已读，false: 未读
   */
  read: boolean;
}