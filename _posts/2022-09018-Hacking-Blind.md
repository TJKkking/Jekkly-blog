---
layout: post
title: "🛡【Cybersecurity】Hacking Blind论文阅读"
categories: security
author: "ooTao"
typora-root-url: ..
---



## 1. 目标&前提

目标：通过ROP的方法远程攻击某个应用程序，劫持该应用程序的控制流。我们可以不需要知道该应用程序的源代码或者任何二进制代码，该应用程序可以被现有的一些保护机制如NX, ASLR, PIE, 以及stack canaries等保护，应用程序所在的服务器可以是32位系统或者64位系统。

初看这个目标感觉实现起来特别困难。其实这个攻击有两个前提条件的：

- 必须先存在一个已知的stack overflow的漏洞，而且攻击者知道如何触发这个漏洞；
- 服务器进程在crash之后会重新复活，并且复活的进程不会被re-rand（意味着虽然有ASLR的保护，但是复活的进程和之前的进程的地址随机化是一样的）。这个需求其实是合理的，因为当前像nginx, MySQL, Apache, OpenSSH, Samba等服务器应用都是符合这种特性的。

##  2. Intro to Buffer Overflows&ROP

#### 防护手段

**NX**: no-execute，支持 NX 位的[操作系统](https://en.wikipedia.org/wiki/Operating_system)可能会将内存的某些区域标记为不可执行。然后，处理器将拒绝执行驻留在这些内存区域中的任何代码。[executable space protection](https://en.wikipedia.org/wiki/Executable_space_protection)。

**ASLR**:  Address space layout randomization，简单来说ASLR通过随机放置进程关键数据区域的[地址空间](https://baike.baidu.com/item/地址空间?fromModule=lemma_inlink)来防止攻击者能可靠地跳转到内存的特定位置来利用函数。

**Stack Canary**: Canary的值是栈上的一个随机数，在程序启动时随机生成并保存在比函数返回地址更低的位置。由于栈溢出是从低地址向高地址进行覆盖，因此攻击者要想控制函数的返回指针，就一定要先覆盖到Canary。程序只需要在函数返回前检查Canary是否被篡改，就可以达到保护栈的目的。

通常可分为三类：

- **Terminator canaries**：由于许多栈溢出都是由于字符串操作（如strcpy）不当所产生的，而这些字符串由NULL“\x00”结尾，换个角度看就是会被“\x00”所截断。基于这一点，terminator canaries将低位设置为“\x00”，既可以防止被泄露，也可以防止被伪造，截断字符还包括CR(0x0d),LF(0x0a),EOF(0xff)。
- **Random canaries：**为了防止canaries被攻击者猜到，random canaries通常在程序初始化时就随机生成，并保存在一个相对安全的地方。当然如果攻击者知道他的位置，还是有可能被读出来的，随机数通常由/dev/urandom生成，有时也使用当前时间的哈希。
- **Random XOR canaries：**与random canaries类似，但是多了一个XOR操作，这样无论是canaries被篡改还是与之XOR的控制数据被篡改，都会发生错误，这样就增加了攻击难度。

#### 攻击手段

ROP: 基于现有的代码片段（gadget）构造一个指令序列拿到shell，以执行更多命令。通过链接足够多的gadgets，最终可以构建完整的shellcode。可以绕过NX.

BROP: 绕过ASLR&PIE

#### 基本思路：

1. Break ASLR——Stack reading

2. Leak binary——BROP
   1. Remotely find enough gadgets to call write()
   2. write() binary from memory to network to  disassemble and find more gadgets to finish  off exploit.
3. Build the exploit

攻击成功实施需要两类新的技术：

- Generalized stack reading: 可以攻击在崩溃后不重新随机化的PIE服务器（即，fork-only-without-execve），在所有情况下，BROP攻击都不能有效应对崩溃后重新随机化（例如execve）的PIE服务器。
- Blind ROP: remotely locates ROP gadgets

<img src="/media/20210705181312429.png" alt="20210705181312429" style="zoom:80%;" />

## 3.Attack

The BROP attack has the following phases:

- Stack reading: read the stack to leak canaries and a return address to defeat ASLR.
- Blind ROP: find enough gadgets to invoke write and control its arguments.
- Build the exploit: dump enough of the binary to find enough gadgets to build a shellcode, and launch the final exploit.

#### Stack reading

思路：64位操作系统通常有8byte的Canary，逐个字节溢出赋值，直至找出正确Canary，此过程还可以找到saced frame pointer & saved return address.

注意：**将栈读取技术应用于除Canary之外的其他值时，存在一些区别。**通常情况下，堆栈读取不一定会返回堆栈上存在的准确的已保存指令指针。返回的值可能稍有不同，这取决于另一个值是否能使程序继续执行而不会导致崩溃。This is OK as the attacker is searching for any valid value in the .text segment range and not for a specific one.

<img src="/media/20210706034454919.png" alt="20210706034454919" style="zoom:80%;" />

#### BROP

#### Finding gadget

方法是用指向text的地址覆盖保存的返回地址并检查程序行为，

为了找这几个gadget需要先找到**stop gadget**——一般情况下，如果我们把栈上的return address覆盖成某些我们随意选取的内存地址的话，程序有很大可能性会挂掉（比如，该return address指向了一段代码区域，里面会有一些对空指针的访问造成程序crash，从而使得攻击者的连接（connection）被关闭）。但是，存在另外一种情况，即该return address指向了一块代码区域，当程序的执行流跳到那段区域之后，程序并不会crash，而是进入了无限循环，指向导致无限循环并保持连接打开。于是我们把这种类型的gadget称为stop gadget。

**如何使用stop gadget？**

直接使用这种技术查找gadgets的一个问题是：即使返回地址被像pop rdi;ret这样的gadget覆盖，应用程序仍可能崩溃，因为它最终将尝试返回到堆栈上的下一个word，这很可能是一个无效的地址。

要扫描有用的gadgets，可以将要探测的地址放在返回地址中，而后紧跟一定数量的stop gadgets。

现在可以扫描整个.text段并得到**gadget列表。**

**识别gadget**

**<img src="/media/2021070610172631.png" alt="2021070610172631" style="zoom:80%;" />**

前两个——找BROP gadget

pop rdx——PLT, strcmp

调用write，写socket，确定socket文件描述符，dump .text段，反编译寻找更多gadget。
