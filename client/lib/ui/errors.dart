String explainError(Object error, bool chinese) {
  final code = error.toString();
  final messages = <String, List<String>>{
    'AUTH_REQUIRED': ['Sign in before continuing.', '请先登录。'],
    'SESSION_EXPIRED': [
      'Your session expired or was revoked. Sign in again.',
      '登录已过期或被撤销，请重新登录。',
    ],
    'INVALID_CREDENTIALS': [
      'Account or password is incorrect, or this account is disabled.',
      '账号或密码不正确，或账号已被禁用。',
    ],
    'LOGIN_RATE_LIMIT': [
      'Too many login attempts. Wait one minute.',
      '登录尝试过多，请等待一分钟。',
    ],
    'HTTPS_ADDRESS_REQUIRED': [
      'Enter a complete HTTPS service address.',
      '请填写完整的 HTTPS 服务地址。',
    ],
    'LINK_REQUIRED': [
      'Scan and establish a new control link.',
      '请扫描并重新建立控制连接。',
    ],
    'SCAN_REQUIRED': [
      'Scan this node again before linking.',
      '请先重新扫描该节点，再建立连接。',
    ],
    'LINK_EXPIRED': [
      'The control link expired. Establish a new link.',
      '控制连接已过期，请重新建立连接。',
    ],
    'STALE_NODE_VERSION': [
      'The node changed. Review its latest state before retrying.',
      '节点状态已改变，请检查最新状态后重新操作。',
    ],
    'IMPACT_CHANGED': [
      'The impact changed. Review and confirm a new request.',
      '影响范围已改变，请重新检查并确认。',
    ],
    'CONFIRMATION_REQUIRED': [
      'This action requires a current impact confirmation.',
      '此操作需要有效的影响确认，请重新确认。',
    ],
    'UPSTREAM_UNAVAILABLE': [
      'An upstream power or network node is unavailable. Restore it first.',
      '上游供电或网络节点不可用，请先恢复上游。',
    ],
    'CONNECTION_LOST': [
      'Connection lost. Controls are disabled until synchronization completes.',
      '连接已中断，完成同步前控制功能不可用。',
    ],
    'NODE_OFFLINE': [
      'This node is offline; this action is unavailable.',
      '节点已离线，当前操作不可用。',
    ],
    'CONTROL_FORBIDDEN': ['Your role has read-only access.', '当前角色只有只读权限。'],
    'ADMIN_REQUIRED': ['Administrator access is required.', '此操作需要管理员权限。'],
    'LAST_ADMIN_REQUIRED': [
      'Keep at least one enabled administrator.',
      '必须保留至少一个启用的管理员。',
    ],
    'USERNAME_EXISTS': ['This member name already exists.', '该成员账号已存在。'],
    'COMMAND_OUTCOME_UNKNOWN': [
      'Command outcome is unknown. Inspect state and audit before submitting another command.',
      '命令结果暂时未知。再次提交前请检查状态与审计记录。',
    ],
  };
  final known = messages[code];
  return '${known == null ? (chinese ? '请求未完成，请检查连接及输入。' : 'Request did not complete. Check connection and input.') : known[chinese ? 1 : 0]}\n$code';
}
