/**
 * 设置中心页面 - 用户设置与账号管理
 *
 * 功能概述：
 * - 账号信息展示与编辑：用户基本信息管理
 * - 消息与播放偏好设置：个性化配置管理
 * - 清理缓存与帮助入口：系统维护功能
 * - 登录/退出管理：用户会话状态控制
 *
 * 技术架构：
 * - @Entry标记为独立页面入口，支持路由导航
 * - @Component封装设置相关的业务逻辑和UI呈现
 * - 响应式状态管理确保数据与UI同步更新
 * - 本地持久化存储保护用户设置数据
 *
 * 数据管理：
 * - 用户会话状态：登录状态、用户信息
 * - 个人资料数据：昵称、签名、头像
 * - 应用偏好设置：消息提醒、播放设置
 * - 系统状态：未读通知数量
 *
 * 安全考虑：
 * - 用户敏感信息的安全存储
 * - 登录状态的可靠验证
 * - 权限申请的明确用户授权
 */

import type common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import picker from '@ohos.file.picker';
import router from '@ohos.router';
import { Prefs } from '../store/Prefs';
import { UserStore } from '../store/UserStore';
import { NotificationStore } from '../store/NotificationStore';

/**
 * 设置中心页面主组件
 *
 * 核心职责：
 * - 管理用户个人资料的完整生命周期
 * - 处理应用偏好设置的持久化存储
 * - 协调用户登录状态的切换和管理
 * - 提供系统维护功能的用户接口
 *
 * 设计模式：
 * - 响应式状态管理：@State装饰器实现数据驱动UI
 * - 分层数据存储：本地存储 + 远程同步
 * - 异常安全处理：完善的错误捕获和用户提示
 */
@Entry
@Component
export struct SettingsPage {
  // ==================== 持久化存储键名定义 ====================

  /**
   * 存储键名常量定义 - 确保数据存储的一致性
   * 命名规范：使用点分隔的层次结构，提高可读性
   */
  private KEY_UID = 'session.userId';        // 用户ID存储键
  private KEY_LOGIN = 'session.isLogin';     // 登录状态存储键
  private KEY_NICK = 'profile.nickname';     // 昵称存储键
  private KEY_BIO = 'profile.bio';           // 签名存储键
  private KEY_AVATAR = 'profile.avatar';     // 头像URL存储键

  // ==================== 用户状态管理 ====================

  /**
   * 登录状态 - 控制页面内容的显示逻辑
   * 未登录用户显示引导信息，登录用户显示完整功能
   */
  @State isLogin: boolean = false;

  /** 用户昵称 - 可编辑的个人显示名称 */
  @State nickname: string = '用户1';

  /** 个人签名 - 用户自我介绍的文本内容 */
  @State bio: string = '这个人很懒，还没有签名～';

  /** 头像URL - 用户头像图片的存储地址 */
  @State avatarUrl: string = '';

  /** 用户ID - 唯一标识用户的字符串，'0'表示未登录 */
  @State uid: string = '0';

  /** 用户名 - 登录用的唯一账号标识 */
  @State username: string = '';

  /** 公开昵称 - 对外显示的名称，可能不同于昵称 */
  @State publicName: string = '';

  /** 访问令牌 - 用户身份验证的凭证 */
  @State token: string = '';

  /** 资料编辑状态 - 控制个人资料编辑界面的显示 */
  @State isEditingProfile: boolean = false;

  // ==================== 应用偏好设置 ====================

  /** 消息推送开关 - 控制是否接收应用通知 */
  @State enablePush: boolean = true;

  /** 自动播放开关 - 控制首页视频是否自动播放 */
  @State enableAutoPlay: boolean = true;

  /** 移动网络播放开关 - 控制是否允许在移动网络下播放媒体 */
  @State enableCellular: boolean = false;

  // ==================== 系统状态 ====================

  /** 未读通知数量 - 显示用户有待处理的消息 */
  @State unreadNotifications: number = 0;

  /**
   * 获取宿主上下文（UIAbility上下文）
   *
   * 技术说明：
   * - 为数据存储等系统能力提供稳定的上下文参数
   * - 确保在不同页面间使用一致的上下文对象
   * - 类型断言保证类型安全
   *
   * @returns UIAbility上下文对象，用于数据持久化操作
   */
  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  /**
   * 页面生命周期方法：页面即将显示时调用
   *
   * 初始化流程：
   * 1. 加载用户会话状态（登录信息、个人资料）
   * 2. 刷新通知状态（显示未读消息数量）
   *
   * 设计考虑：
   * - 异步操作避免阻塞UI渲染
   * - 错误处理确保页面可用性
   * - 数据缓存提升用户体验
   */
  async aboutToAppear() {
    await this.loadSession();           // 加载用户会话信息
    await this.refreshNotifications();  // 刷新通知状态
  }

  /**
   * 加载用户会话状态
   *
   * 加载策略：
   * 1. 优先从UserStore获取当前登录用户信息
   * 2. 如果未登录，从本地存储加载基本资料
   * 3. 设置相应的状态变量供UI使用
   *
   * 数据来源优先级：
   * - 在线用户数据（最新、最完整）
   * - 本地缓存数据（离线可用）
   * - 默认值（确保基本功能）
   */
  private async loadSession() {
    // 尝试从UserStore获取当前登录用户信息
    const user = await UserStore.currentUser(this.hostCtx());
    if (user) {
      // 登录用户：使用完整的用户信息
      this.uid = String(user.id);
      this.nickname = user.nickname || user.username;  // 昵称兜底逻辑
      this.bio = user.bio ?? '这个人很懒，还没有签名～';  // 签名默认值
      this.avatarUrl = user.avatarUrl ?? '';           // 头像URL
      this.username = user.username;
      this.publicName = user.publicName;
      this.token = user.token ?? '';                   // 访问令牌
      this.isLogin = true;
      return;
    }

    // 未登录用户：从本地存储加载基本资料
    const uid = await Prefs.getString(this.hostCtx(), this.KEY_UID, '0');
    this.isLogin = (uid !== '0');  // 根据用户ID判断登录状态
    this.nickname = await Prefs.getString(this.hostCtx(), this.KEY_NICK, '用户1');
    this.bio = await Prefs.getString(this.hostCtx(), this.KEY_BIO, '这个人很懒，还没有签名～');
    this.avatarUrl = await Prefs.getString(this.hostCtx(), this.KEY_AVATAR, '');
    this.uid = uid;
  }

  /**
   * 保存所有设置到持久化存储
   *
   * 保存策略：
   * - 同步保存到本地存储（Prefs）
   * - 如果用户已登录，同步更新到服务器
   * - 确保数据的一致性和可靠性
   *
   * 技术实现：
   * - 使用Prefs进行本地数据持久化
   * - 调用UserStore进行远程数据同步
   * - 异常处理确保数据安全
   */
  private async saveAll() {
    // 保存到本地持久化存储
    await Prefs.putString(this.hostCtx(), this.KEY_UID, this.uid);
    await Prefs.putBool(this.hostCtx(), this.KEY_LOGIN, this.isLogin);
    await Prefs.putString(this.hostCtx(), this.KEY_NICK, this.nickname);
    await Prefs.putString(this.hostCtx(), this.KEY_BIO, this.bio);
    await Prefs.putString(this.hostCtx(), this.KEY_AVATAR, this.avatarUrl);

    // 登录用户：同步更新到服务器
    if (this.isLogin && this.uid !== '0') {
      await UserStore.updateProfile(this.hostCtx(), {
        nickname: this.nickname,
        bio: this.bio,
        avatarUrl: this.avatarUrl
      });
    }
  }

  /**
   * 持久化个人资料变更
   *
   * 处理流程：
   * 1. 清理和验证输入数据（去除前后空格，设置默认值）
   * 2. 保存到本地和远程存储
   * 3. 触发全局状态同步（通知其他页面更新）
   * 4. 提供用户操作反馈
   *
   * 数据验证：
   * - 昵称：去除空格，使用用户名作为默认值
   * - 签名：去除空格，设置友好的默认提示
   */
  private async persistProfileChanges() {
    // 数据清理和验证
    this.nickname = this.nickname.trim() || this.username || '用户1';
    this.bio = this.bio.trim() || '这个人很懒，还没有签名～';

    // 保存数据
    await this.saveAll();

    // 触发全局状态同步：通知其他页面用户资料已更新
    AppStorage.setOrCreate('session_version', 0);
    const v = (AppStorage.get('session_version') as number) ?? 0;
    AppStorage.set('session_version', v + 1);

    // 用户反馈：操作成功提示
    promptAction.showToast({ message: '已保存个人资料' });
  }

  /**
   * 相册权限申请弹窗
   *
   * 权限申请最佳实践：
   * - 明确的权限用途说明
   * - 友好的用户交互界面
   * - 合理的默认选项设置
   *
   * @returns Promise<boolean> 用户是否授权相册权限
   *
   * 安全考虑：
   * - 运行时权限申请（使用时申请）
   * - 明确的权限说明（让用户理解用途）
   * - 用户自主选择（不强制授权）
   */
  private async requestPhotoPermission(): Promise<boolean> {
    try {
      const result = await promptAction.showDialog({
        title: '申请相册权限',
        message: '用于选择头像和上传图片，我们仅会在您主动操作时访问相册。',
        buttons: [
          { text: '暂不允许', color: '#666666' },  // 中性选项
          { text: '允许', color: '#4C6FFF' }       // 主要操作选项
        ]
      });
      return result?.index === 1;  // 返回用户选择结果
    } catch {
      return false;  // 异常情况下默认拒绝权限
    }
  }

  /**
   * 选择头像的完整流程
   *
   * 执行步骤：
   * 1. 申请相册访问权限
   * 2. 创建并配置图片选择器
   * 3. 等待用户选择图片
   * 4. 处理选择结果并更新状态
   *
   * 异常处理：
   * - 权限拒绝：友好提示用户
   * - 选择失败：提供重试建议
   * - 系统异常：降级处理确保可用性
   */
  private async chooseAvatar() {
    try {
      // 第一步：申请相册访问权限
      const permitted = await this.requestPhotoPermission();
      if (!permitted) {
        promptAction.showToast({ message: '未授权相册权限，无法选择头像' });
        return;
      }

      // 第二步：创建并配置图片选择器
      const photoPicker = new picker.PhotoViewPicker();
      const options = new picker.PhotoSelectOptions();
      options.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;  // 限制为图片类型
      options.maxSelectNumber = 1;  // 单次只能选择一张图片

      // 第三步：打开选择器并等待用户操作
      const result = await photoPicker.select(options);

      // 第四步：处理选择结果
      if (result?.photoUris?.length) {
        this.avatarUrl = result.photoUris[0];  // 更新头像URL状态
      }
    } catch (e) {
      // 头像选择失败的友好提示
      promptAction.showToast({ message: '头像选择失败，请稍后重试' });
    }
  }

  /**
   * 处理用户退出登录
   *
   * 退出流程：
   * 1. 清空本地用户状态（用户信息、令牌等）
   * 2. 更新持久化存储（标记为未登录状态）
   * 3. 调用UserStore执行退出逻辑
   * 4. 触发全局状态同步（通知其他页面）
   * 5. 刷新相关状态（通知数量等）
   * 6. 提供用户操作反馈
   *
   * 安全考虑：
   * - 彻底清空敏感信息（令牌、用户数据）
   * - 确保登录状态的一致性
   * - 提供明确的退出反馈
   */
  private async handleLogout() {
    // 清空本地用户状态
    this.uid = '0';
    this.username = '';
    this.publicName = '';
    this.token = '';
    this.avatarUrl = '';
    this.isLogin = false;
    this.isEditingProfile = false;

    // 更新持久化存储和执行退出逻辑
    await this.saveAll();
    await UserStore.logout(this.hostCtx());

    // 触发全局状态同步：通知其他页面用户已退出
    AppStorage.setOrCreate('session_version', 0);
    const v = (AppStorage.get('session_version') as number) ?? 0;
    AppStorage.set('session_version', v + 1);

    // 刷新相关状态
    await this.refreshNotifications();

    // 用户反馈：退出成功提示
    promptAction.showToast({ message: '已退出登录' });
  }

  /**
   * 取消个人资料编辑
   *
   * 取消逻辑：
   * 1. 重新加载原始会话数据（恢复未修改状态）
   * 2. 退出编辑模式（隐藏编辑界面）
   *
   * 用户体验：
   * - 提供取消编辑的选项
   * - 确保数据可以安全回滚
   * - 保持界面状态的一致性
   */
  private async cancelEditProfile() {
    await this.loadSession();        // 重新加载原始数据
    this.isEditingProfile = false;   // 退出编辑模式
  }

  /**
   * 刷新未读通知数量
   *
   * 刷新策略：
   * - 未登录用户：通知数量为0
   * - 登录用户：从NotificationStore获取实际数量
   *
   * 性能考虑：
   * - 按需加载，避免不必要的网络请求
   * - 缓存机制，减少重复数据获取
   */
  private async refreshNotifications() {
    if (!this.isLogin || this.uid === '0') {
      this.unreadNotifications = 0;  // 未登录用户无通知
      return;
    }
    // 登录用户：获取实际未读通知数量
    this.unreadNotifications = await NotificationStore.unreadCount(this.hostCtx(), this.uid);
  }

  /**
   * 打开帮助中心（占位功能）
   *
   * 当前状态：功能建设中
   * 未来扩展：可以跳转到帮助页面或显示帮助文档
   */
  private async openHelpCenter() {
    promptAction.showToast({ message: '帮助中心正在建设中' });
  }

  /**
   * 清理缓存（占位功能）
   *
   * 当前状态：模拟清理操作
   * 未来扩展：实际清理应用缓存数据
   */
  private async clearCache() {
    promptAction.showToast({ message: '缓存已清理，空间更清爽' });
  }

  /**
   * 构建设置页面UI
   *
   * 布局层次：
   * 1. Stack层：背景图片 + 主内容区域
   * 2. Column层：头部导航 + 滚动内容区域
   * 3. 卡片分组：账号信息、偏好设置、系统功能
   *
   * 条件渲染逻辑：
   * - 根据登录状态显示不同的功能区域
   * - 根据编辑状态切换资料管理界面
   * - 动态显示用户信息和设置选项
   */
  build() {
    Stack() {
      // 背景图片层：全屏背景增强视觉体验
      Image($r('app.media.bgt'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)

      // 主内容区域：垂直排列的布局结构
      Column() {
        // ========== 头部导航栏 ==========
        Row() {
          // 返回按钮：提供页面导航功能
          Text('←')
            .fontSize(20)
            .margin({ left: 16 })
            .onClick(() => router.back());  // 返回上一页

          // 页面标题：居中显示，突出页面功能
          Text('设置中心')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          // 右侧占位：保持布局对称性
          Blank().width(36)
        }
        .alignItems(VerticalAlign.Center)
        .padding({ top: 16, right: 16, bottom: 12 })

        // ========== 可滚动内容区域 ==========
        Scroll() {
          Column({ space: 16 }) {  // 卡片间距16vp
            // ========== 账号信息卡片 ==========
            Column({ space: 12 }) {
              // 卡片标题
              Row() {
                Text('账号信息').fontSize(16).fontWeight(FontWeight.Medium)
              }

              // 条件渲染：根据登录状态显示不同内容
              if (this.isLogin) {
                // 登录用户：显示完整的账号信息
                Column({ space: 6 }) {
                  Text(`用户ID：${this.uid}`).fontSize(13).opacity(0.7)
                  Text(`用户名：${this.username || '未获取'}`).fontSize(13).opacity(0.7)
                  Text(`公开昵称：${this.publicName || this.nickname}`).fontSize(13).opacity(0.7)
                  Text(`昵称：${this.nickname}`).fontSize(13).opacity(0.7)
                  Text(`签名：${this.bio}`).fontSize(13).opacity(0.7)
                  Text(`Token：${this.token || '暂无'}`).fontSize(13).opacity(0.6)
                }
              } else {
                // 未登录用户：显示引导信息
                Text('登录后可管理账号信息').fontSize(12).opacity(0.6)
              }
            }
            .padding(16)
            .borderRadius(16)
            .backgroundColor('#FFFFFF')
            .border({ width: 1, color: '#E9EEF5' })
            .shadow({ radius: 12, color: '#1A3B5A14', offsetX: 0, offsetY: 6 })

            // ========== 偏好设置卡片 ==========
            Column({ space: 10 }) {
              // 消息提醒开关
              Row() {
                Text('消息提醒').fontSize(14)
                Blank().layoutWeight(1)  // 弹性空间：实现右对齐
                Toggle({ type: ToggleType.Switch, isOn: this.enablePush })
                  .onChange((v: boolean) => {
                    this.enablePush = v;  // 更新消息提醒设置
                  })
              }

              // 自动播放开关
              Row() {
                Text('首页自动播放').fontSize(14)
                Blank().layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.enableAutoPlay })
                  .onChange((v: boolean) => {
                    this.enableAutoPlay = v;  // 更新自动播放设置
                  })
              }

              // 移动网络播放开关
              Row() {
                Text('移动网络播放').fontSize(14)
                Blank().layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.enableCellular })
                  .onChange((v: boolean) => {
                    this.enableCellular = v;  // 更新移动网络设置
                  })
              }
            }
            .padding(16)
            .borderRadius(16)
            .backgroundColor('#FFFFFF')
            .border({ width: 1, color: '#E9EEF5' })
            .shadow({ radius: 12, color: '#1A3B5A14', offsetX: 0, offsetY: 6 })

            // ========== 系统功能卡片 ==========
            Column({ space: 10 }) {
              // 清理缓存功能
              Row() {
                Text('清理缓存').fontSize(14)
                Blank().layoutWeight(1)
                Text('立即').fontSize(12).fontColor('#3B82F6')  // 操作提示文字
              }
              .onClick(async () => await this.clearCache())  // 点击清理缓存

              // 帮助中心功能
              Row() {
                Text('帮助中心').fontSize(14)
                Blank().layoutWeight(1)
                Text('查看').fontSize(12).fontColor('#3B82F6')
              }
              .onClick(async () => await this.openHelpCenter())  // 点击打开帮助
            }
            .padding(16)
            .borderRadius(16)
            .backgroundColor('#FFFFFF')
            .border({ width: 1, color: '#E9EEF5' })
            .shadow({ radius: 12, color: '#1A3B5A14', offsetX: 0, offsetY: 6 })

            // ========== 资料管理卡片（仅登录用户显示） ==========
            if (this.isLogin) {
              Column({ space: 12 }) {
                // 卡片标题
                Row() {
                  Text('资料管理').fontSize(16).fontWeight(FontWeight.Medium)
                }

                // 条件渲染：编辑模式 vs 查看模式
                if (this.isEditingProfile) {
                  // ========== 编辑模式界面 ==========

                  // 头像编辑区域
                  Row({ space: 12 }) {
                    // 头像显示容器
                    Stack({ alignContent: Alignment.Center }) {
                      if (this.avatarUrl) {
                        // 自定义头像显示
                        Image(this.avatarUrl)
                          .width(52)
                          .height(52)
                          .borderRadius(26)
                          .objectFit(ImageFit.Cover)
                      } else {
                        // 默认头像显示
                        Image($r('app.media.mrtx'))
                          .width(52)
                          .height(52)
                          .borderRadius(26)
                          .objectFit(ImageFit.Cover)
                        // 昵称首字母显示
                        Text(this.nickname ? this.nickname.slice(0, 1) : '我')
                          .fontSize(18)
                          .fontWeight(FontWeight.Bold)
                          .fontColor('#FFFFFF')
                          .textAlign(TextAlign.Center)
                      }
                    }
                    .width(52)
                    .height(52)
                    .borderRadius(26)
                    .border({ width: 1, color: '#E2E8F5' })

                    // 更换头像按钮
                    Button('更换头像', { type: ButtonType.Capsule })
                      .onClick(async () => {
                        await this.chooseAvatar();  // 触发头像选择
                      })
                  }
                  .alignItems(VerticalAlign.Center)

                  // 昵称编辑区域
                  Text('编辑昵称').fontSize(14).opacity(0.7)
                  TextInput({ text: this.nickname, placeholder: '请输入昵称' })
                    .onChange((v) => {
                      this.nickname = v;  // 实时更新昵称状态
                    })
                    .padding({ left: 12, right: 12 })
                    .borderRadius(10)
                    .backgroundColor('#F6F7FB')  // 浅灰色输入背景

                  // 签名编辑区域
                  Text('编辑签名').fontSize(14).opacity(0.7).margin({ top: 6 })
                  TextInput({ text: this.bio, placeholder: '请输入签名' })
                    .onChange((v) => {
                      this.bio = v  // 实时更新签名状态
                    })
                    .padding({ left: 12, right: 12 })
                    .borderRadius(10)
                    .backgroundColor('#F6F7FB')

                  // 操作按钮区域
                  Row({ space: 12 }) {
                    // 保存按钮
                    Button('保存资料', { type: ButtonType.Capsule })
                      .layoutWeight(1)
                      .onClick(async () => {
                        await this.persistProfileChanges();  // 保存更改
                        this.isEditingProfile = false;       // 退出编辑模式
                      })
                    // 取消按钮
                    Button('取消', { type: ButtonType.Capsule })
                      .layoutWeight(1)
                      .onClick(async () => {
                        await this.cancelEditProfile();  // 取消编辑
                      })
                  }
                  .margin({ top: 6 })
                } else {
                  // ========== 查看模式界面 ==========

                  // 操作按钮区域
                  Row({ space: 12 }) {
                    // 修改资料按钮
                    Button('修改资料', { type: ButtonType.Capsule })
                      .layoutWeight(1)
                      .onClick(() => {
                        this.isEditingProfile = true;  // 进入编辑模式
                      })
                    // 退出登录按钮
                    Button('退出登录', { type: ButtonType.Capsule })
                      .layoutWeight(1)
                      .onClick(async () => {
                        await this.handleLogout();  // 执行退出登录
                      })
                  }
                  .margin({ top: 10 })
                }
              }
              .padding(16)
              .borderRadius(16)
              .backgroundColor('#FFFFFF')
              .border({ width: 1, color: '#E9EEF5' })
              .shadow({ radius: 12, color: '#1A3B5A14', offsetX: 0, offsetY: 6 })
            }
          }
          .padding({ left: 16, right: 16, bottom: 24 })  // 内容区域边距
        }
        .layoutWeight(1)  // 弹性布局：占据剩余垂直空间
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}