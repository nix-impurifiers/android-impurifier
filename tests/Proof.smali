.class public Lorg/niximpurifiers/Proof;
.super Landroid/app/Activity;

.method static constructor <clinit>()V
    .locals 1
    const-string v0, "proof"
    invoke-static {v0}, Ljava/lang/System;->loadLibrary(Ljava/lang/String;)V
    return-void
.end method

.method public constructor <init>()V
    .locals 0
    invoke-direct {p0}, Landroid/app/Activity;-><init>()V
    return-void
.end method

.method private static native value()I
.end method

.method public onCreate(Landroid/os/Bundle;)V
    .locals 2
    invoke-super {p0, p1}, Landroid/app/Activity;->onCreate(Landroid/os/Bundle;)V
    invoke-static {}, Lorg/niximpurifiers/Proof;->value()I
    move-result v0
    invoke-static {v0}, Ljava/lang/Integer;->toString(I)Ljava/lang/String;
    move-result-object v1
    const-string v0, "ImpurifierProof"
    invoke-static {v0, v1}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I
    new-instance v0, Landroid/widget/TextView;
    invoke-direct {v0, p0}, Landroid/widget/TextView;-><init>(Landroid/content/Context;)V
    invoke-virtual {v0, v1}, Landroid/widget/TextView;->setText(Ljava/lang/CharSequence;)V
    invoke-virtual {p0, v0}, Landroid/app/Activity;->setContentView(Landroid/view/View;)V
    return-void
.end method
