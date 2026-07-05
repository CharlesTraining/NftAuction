# AGENTS.md

# Crowdfunding DApp Development Rules

本文件用于约束 AI Agent（Codex、Claude Code、Cursor）以及开发人员的行为。

目标：

- 统一技术栈
- 统一开发规范
- 保证代码质量
- 保证安全性
- 保证可测试性
- 保证可维护性
- 使用中文

---

# 1. 技术栈（固定，不允许随意替换）

## Smart Contract

Language

- Solidity ^0.8.24

Framework

- Foundry

Libraries

- OpenZeppelin v5.x

Tools

- forge
- cast
- anvil

Dependencies

- forge-std

Static Analysis

- slither

Gas Analysis

- forge snapshot

Coverage

- forge coverage

Formatter

- forge fmt

---

## Frontend

Framework

- Next.js 15

Language

- TypeScript

UI

- TailwindCSS v4
- shadcn/ui

Web3

-  ethers.js
- wagmi
- viem
- RainbowKit

State

- Zustand

Form

- React Hook Form
- zod

---

## Backend（可选）

仅做索引与缓存。

禁止存储业务真相。

Framework

- NestJS

Database

- PostgreSQL

ORM

- Prisma

Cache

- Redis

Queue

- BullMQ

---

## Indexer

优先：

- Ponder

备选：

- The Graph

---

## CI/CD

- Github Actions
- Docker

---

# 2. AI 开发流程（强制）

禁止直接开始编码。

每个任务必须遵循：

Step 1

需求分析

Step 2

技术方案设计

Step 3

模块拆分

Step 4

接口设计

Step 5

测试设计

Step 6

编码

Step 7

验证

禁止跳过步骤。

---

# 3. Solidity 编码规范

每个文件职责单一。

一个合约只负责一类业务。

禁止出现 God Contract（巨型合约）。

目录结构：

contracts/

interfaces/

libraries/

core/

factory/

events/

errors/

types/

utils/

---

## 文件命名

PascalCase

例如：

CrowdfundingFactory.sol

CrowdfundingProject.sol

ProjectVault.sol

---

## 变量命名

状态变量

camelCase

```solidity
goalAmount
currentAmount
projectCount
```

常量

```solidity
MAX_DURATION
MIN_CONTRIBUTION
```

immutable

```solidity
factory
treasury
```

---

# 4. 必须使用的 Solidity 特性

必须：

- custom error
- event
- immutable
- constant
- modifier
- interface

优先：

- library
- struct
- enum

---

# 5. 禁止事项

禁止：

tx.origin

transfer()

selfdestruct()

abi.encodePacked 多动态参数

console.log 提交生产环境

硬编码地址

magic number

超大函数（>100行）

超大合约（>600行）

深层嵌套（>3层）

重复代码

业务逻辑写在 constructor

---

# 6. 安全规范（强制）

必须实现：

CEI Pattern

Checks

Effects

Interactions

---

必须使用：

ReentrancyGuard

Pausable

Ownable 或 AccessControl

Input Validation

Deadline Validation

Amount Validation

Permission Validation

Event Logging

---

禁止：

Push Payment

允许：

Pull Payment

---

所有外部调用必须：

```solidity
(bool success,) = addr.call{value:amount}("");

if(!success){
    revert TransferFailed();
}
```

---

# 7. Event规范

每个关键业务必须记录Event。

必须包含：

ProjectCreated

ContributionAdded

ProjectCancelled

ProjectSucceeded

ProjectFailed

FundsWithdrawn

RefundClaimed

---

# 8. Error规范

禁止：

```solidity
require(x,"error");
```

使用：

```solidity
error Unauthorized();

error InvalidAmount();

error DeadlinePassed();

error GoalNotReached();
```

---

# 9. Gas优化规范

优先级：

1 immutable

2 constant

3 storage cache

4 unchecked

5 custom error

6 calldata

7 event替代存储

8 减少SLOAD

禁止：

大量循环

链上排序

链上分页

链上复杂计算

---

# 10. 测试规范（强制）

测试覆盖率：

>=95%

必须编写：

Unit Test

Integration Test

Fuzz Test

Invariant Test

Attack Test

Edge Case Test

---

# 11. 攻击测试

必须模拟：

重入攻击

越权调用

重复提款

时间边界

异常状态切换

DOS攻击

恶意用户调用

极端金额输入

---

# 12. Frontend规范

禁止：

直接调用RPC

必须：

wagmi + viem


---

数据获取：

React Query

状态：

Zustand

表单：

React Hook Form + zod

---

# 13. Typescript规范

禁止：

any

允许：

unknown

必须：

strict:true

必须：

定义类型

禁止：

超大组件

单组件：

<=300行

单函数：

<=50行

---

# 14. Git规范

Commit：

feat:

fix:

refactor:

test:

docs:

chore:

perf:

---

# 15. AI Agent 输出规范（强制）

每次开发任务必须先输出：

1. Requirement

2. Architecture

3. Interface

4. Security

5. Testing

6. Implementation

最后再编码。

禁止直接输出代码。

# 16. 文档与注释规范（强制）

目标：

让代码具备长期可维护性。

注释用于解释：

- 为什么这样设计（Why）
- 业务规则（Business Rule）
- 风险点（Risk）
- 边界条件（Edge Case）

禁止解释显而易见的代码（What）。

---

## 必须添加注释的位置

### 1. 合约文件头

每个 Solidity 文件必须包含说明。

示例：

/**
 * @title CrowdfundingProject
 * @author AI Agent
 * @notice 单个众筹项目合约
 * @dev 负责接收资金、状态管理、提款和退款
 */

---

### 2. Struct

必须添加注释

示例：

/**
 * @dev 众筹项目数据
 */
struct Project {
    uint256 id;
    address creator;
    uint256 goalAmount;
    uint256 currentAmount;
    uint256 deadline;
    ProjectStatus status;
}

---

### 3. Enum

必须添加注释

示例：

/**
 * @dev 项目状态
 */
enum ProjectStatus {
    Draft,
    Active,
    Successful,
    Failed,
    Completed
}

---

### 4. Event

必须添加注释

示例：

/**
 * @dev 创建新项目时触发
 */
event ProjectCreated(
    uint256 indexed projectId,
    address indexed creator
);

---

### 5. Custom Error

必须添加注释

示例：

/// @dev 非项目创建者操作
error Unauthorized();

---

### 6. Public/External函数

必须使用 NatSpec

示例：

/**
 * @notice 用户参与众筹
 * @param amount 贡献金额
 * @dev 仅允许 Active 状态调用
 */
function contribute(
    uint256 amount
) external payable {}

---

### 7. 复杂业务逻辑

必须增加解释

例如：

// 使用 Pull Payment 防止重入攻击
// 用户主动领取退款而不是系统主动转账

// deadline 到达后锁定募集状态

// 缓存 storage 减少 SLOAD 次数

---

### 8. Frontend业务函数

必须添加说明

示例：

/**
 * 获取项目详情并格式化链上数据
 */
async function fetchProject(){}

---

## 禁止事项

禁止：

// i++

i++;

禁止：

// 设置金额

amount = value;

禁止：

// 判断是否为空

if(x == 0)

禁止：

每行代码都写注释

禁止：

复制需求文档作为注释

---

## 注释密度要求

普通代码：

5%~10%

复杂业务：

10%~20%

禁止超过30%

---

## AI Agent 特殊要求

生成代码时默认添加必要注释。

重点说明：

- 为什么这样设计
- 为什么这样实现
- 为什么这样优化

不要解释显而易见的代码。

代码可读性优先于注释数量。