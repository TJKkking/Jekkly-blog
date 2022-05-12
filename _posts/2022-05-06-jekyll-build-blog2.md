---
layout: post
title: "💻【Jekyll】使用Jekyll搭建个人博客（二）"
categories: tutorial
author: "ooTao"
typora-root-url: .. 
---







## 自动部署总体方案

上一篇成功将Jekyll部署到了本地，由此我们可以随心所欲地将博客修改成自己想要的样子。接下来要做的是将博客部署到我们的服务器上。由于Jekyll生成的是静态网站，这意味着我们每对网站进行一次修改，就要重新进行一次构建-发布的流程，那么我们该如何构建一个自动化部署的工作流呢？

我们希望当我们将新内容push到远端，能够有工具自动检测变化，并触发Jekyll的重新构建；也要有工具能够帮助我们监督构建任务的执行状态，在部署出现意外时能够通知到我们。得益于前人的探索实践，我们有现成的工具可以使用。🍭对于构建任务的触发采用Gitee的[WebHooks ](https://gitee.com/JACKYTOO/blog/hooks)功能；对于构建任务的执行及监督使用开源工[Jenkins](https://www.jenkins.io/zh/doc/)。

