title: RPM specfile 中 $1 值的研究
date: 2015-08-28 06:42:10
tags: [Fedora,RPM]
categories: Fedora
---

本博客的开篇，标题借用 Marguerite.su 女王的 《{% link "RPM specfile 中 $1 值的研究" http://www.marguerite.su/2015/08/02/RPM-specfile-%E4%B8%AD-1-%E5%80%BC%E7%9A%84%E7%A0%94%E7%A9%B6/ %}》日志以表敬仰。

## RPM 工作流程
这几天翻译 {% link How to create an RPM package https://fedoraproject.org/wiki/How_to_create_an_RPM_package %}，发现 RPM Spec 不像表面上看着那么简单。下面简述 RPM 工作流程。

- 安装流程：%pre -> 安装文件 -> %post
- 卸载流程：%preun -> 卸载文件 -> %postun
- 升级流程：new-%pre -> 安装文件 -> new-%post -> old-%preun -> 卸载文件 -> old-%postun

在以上流程中，%XXX 阶段执行的脚本被称为 *脚本片段 (Scriptlet)*。它用于在 RPM 包安装/升级/卸载时，对系统执行必要操作。在升级过程中，先安装新包，再卸载旧包。卸载旧包时，不会删除新包已安装的文件，以此完成升级。

假设在 %post 中编写创建文件的脚本，在 %postun 中删除此文件。安装/卸载都很顺利，但升级时问题来了。执行 old-%postun 时，会将 new-%post 中创建的文件删除。为了解决此问题，RPM 向脚本传入一个参数，表示各个阶段此软件包的**数量**。通过判断 $1 参数的值，执行不同动作。

## 参数值列表
另外，RPM 还有许多高级特性，如触发器、事务等。以下列出一个完整的参数值列表，供参考：

|         |Install|Update|Uninstall|
|---------|-------|------|---------|
|%pretrans|$1 = 0 |$1 = 0|(N/A)    |
|%triggerprein | 安装本包：$1 = 0, $2 = 1<br/>安装目标包：$1 = 1, $2 = 0|$1 = 1, $2 = 1|(N/A)|
|%pre | $1 = 1 |$1 = 2|(N/A)|
|%post | $1 = 1 |$1 = 2|(N/A)|
|%triggerin | $1 = 1, $2 = 1|升级本包：$1 = 2, $2 = 1<br/>升级目标包：$1 = 1, $2 = 2|(N/A)|
|%triggerun |(N/A)| $1 = 1, $2 = 1|卸载本包：$1 = 0, $2 = 1<br/>卸载目标包：$1 = 1, $2 = 0|
|%preun |(N/A)| $1 = 1 |$1 = 0|
|%postun |(N/A)| $1 = 1 |$1 = 0|
|%triggerpostun |(N/A)|升级目标包：$1 = 1, $2 = 1|卸载目标包：$1 = 1, $2 = 0|
|%posttrans|$1 = 0 |$1 = 0|(N/A)    |

<br>

## 脚本片段执行顺序
在升级软件包时，脚本片段的完整执行顺序如下：

1. 检查软件包依赖、下载软件包和 DRPM
2. (all)%pretrans：事务开始时，执行新软件包的此段代码
3. ...... (操作其它软件包) ......
4. (any)%triggerprein：此包的新版本安装之前，触发此包或其他包的脚本（如果有）
5. (new)%triggerprein：指定的其他软件包安装之前，触发此脚本
6. (new)%pre：执行新软件包的 %pre 脚本
7. ...... (安装所有新文件) ......
8. (new)%post：执行新软件包的 %post 脚本
9. (any)%triggerin：安装此软件包时，触发此包或其他包的脚本（如果有）
10. (new)%triggerin：安装指定的其他软件包时，触发此脚本
11. (old)%triggerun：卸载指定的其他软件包的旧版本时，触发此脚本
12. (any)%triggerun：卸载此软件包的旧版本时，触发此包或其他包的脚本（如果有）
13. (old)%preun：执行旧软件包的 %preun 脚本
14. ...... (删除所有旧文件) ......
15. (old)%postun：执行旧软件包的 %postun 脚本
16. (old)%triggerpostun：指定的其他软件包的旧版本已卸载之后，触发此脚本
17. (any)%triggerpostun：此包的旧版本已卸载之后，触发其他包的脚本（如果有；此包的脚本只由其他包触发执行，自己不运行）
18. ...... (操作其它软件包) ......
19. (all)%posttrans：事务结束时，执行新软件包的此段代码
20. 验证软件包，Done

以上就是一个完整的 RPM 包升级过程。关于 trigger 的详细信息，请参考 {% link 这里 https://fedoraproject.org/wiki/How_to_create_an_RPM_package/zh-hk#Trigger %}，Done

-- EOF --
