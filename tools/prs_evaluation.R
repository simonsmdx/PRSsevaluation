library("ggplot2")
library("reshape2")
library("dplyr")
library("caret")
library("tidymodels")
library("plotly")
library("htmlwidgets")
library("optparse")   

arg <- list(
	make_option(c("-i", "--input"),
		default="prs_results_dataframe.txt"),
	make_option(c("-o", "--output_dir"),
		default="evaluation")
)
parser <- OptionParser(option_list=arg)
 
opt <- parse_args(parser, arg=commandArgs(trailingOnly=TRUE), positional_arguments=0)$options
input <- opt$i
output_dir <- opt$o
arg = commandArgs(trailingOnly=TRUE)
subdir_plot="plots"
subdir_table="table"
#input=arg[1]
#output_dir=arg[2]
dir.create(file.path(output_dir, subdir_plot), showWarnings = FALSE)
dir.create(file.path(output_dir, subdir_table), showWarnings = FALSE)
setwd(file.path(output_dir))
df <-  read.table(file=input, header = TRUE,sep="\t")
gen_thre <- function(df, val, output){
  df$effect <- "NO"
  df$effect[df[, c(5)] == 1] <- "addicted"
  df$effect[df[, c(5)] == 0] <- "non-addicted"
  Cases <- df$effect
  lower.limit <- min(df[, c(val)])
  upper.limit <- max(df[, c(val)])
  long.density <- density(subset(df, caffeine_addiction == 1)[ ,c(val)], from = lower.limit, to = upper.limit, n = 2^10)
  not.long.density <- density(subset(df, caffeine_addiction == 0)[ ,c(val)], from = lower.limit, to = upper.limit, n = 2^10)
  
  density.difference <- long.density$y - not.long.density$y
  intersection.point <- long.density$x[which(diff(density.difference > 0) != 0) + 1]
  PRS=df[ ,c(val)]
  dens_model_a <- ggplot(data=df, aes(x=PRS, group=caffeine_addiction, fill=Cases)) +
    geom_density(adjust=1, alpha=.4) +
    scale_color_manual(values=Cases)+
    geom_vline(xintercept =intersection.point , col = "red")
  png(output,  width=1500, height=700)
  print(dens_model_a)
  dev.off()
  return(intersection.point)
}

gen_bar_plot <- function(df, x,y,z, output){
  df.long<-df[c(x,y,z)]
  df <- melt(df.long)

  px <- ggplot(df, aes(x=SAMPLE, y=value, fill=variable))+
      geom_bar(stat="identity", position="dodge", width = 1)
  png(output, width=1500, height=700)
  print(px)
  dev.off()
}

gen_box_plot <- function(df, val, output){
  
  PRS <- df[ ,c(val)]
  png(output, width=1500, height=700)
  x <- boxplot(PRS~caffeine_addiction,data=df)
  print(x)
  dev.off()
}

gen_class_df <- function(df, inters, val, output){
  x <- df[, c(val)]
  df_split=df[c(1, val, 5)]
  df_split$Classification_model=as.integer(as.logical(with(df, df[,c(val)] > inters)))
  zscore <- (x - mean(x)) / sd(x)
  p_value <- (2*pnorm(-abs(zscore)))
  df_split$pvalue<- p_value
  write.table(df_split, file = output, , sep="\t", quote=FALSE)
  return (df_split)
}


gen_confusion_matrix <- function(df, output){
  sink(output)
  expected <- factor(df$caffeine_addiction)
  predicted <- factor(df$Classification_model)
  example <- confusionMatrix(data=predicted, reference = expected)
  print(example)
  sink()
}


simple_roc <- function(labels, scores, output){
  labels <- labels[order(scores, decreasing=TRUE)]
  x <-data.frame(TPR=cumsum(labels)/sum(labels), FPR=cumsum(!labels)/sum(!labels), labels)
  png(output, width=1500, height=700)
  plot <- ggplot(x, aes(x=FPR, y=TPR, col=labels))+
    geom_point()+
    geom_line()
  print(plot)
  dev.off()
}


gen_plot_roc_auc <- function(df){
  yscore <- data.frame(df$Classification_model)
  rdb <- cbind(df$caffeine_addiction,yscore)
  colnames(rdb) = c('y','yscore')
  pdb <- roc_curve(rdb, factor(y), yscore)
  pdb$specificity <- 1 - pdb$specificity
  auc = roc_auc(rdb, factor(y), yscore)
  auc = auc$.estimate
  tit = paste('ROC Curve (AUC = ',toString(round(auc,2)),')',sep = '')
  fig <-  plot_ly(data = pdb ,x =  ~specificity, y = ~sensitivity, type = 'scatter', mode = 'lines', fill = 'tozeroy') %>%
  layout(title = tit,xaxis = list(title = "False Positive Rate"), yaxis = list(title = "True Positive Rate")) %>%
  add_segments(x = 0, xend = 1, y = 0, yend = 1, line = list(dash = "dash", color = 'black'),inherit = FALSE, showlegend = FALSE)
}

###########################
######## RESULTS ##########
###########################

output_path_a <- paste(output_dir, "plots/Density_plot_model_a.png", sep="")
output_path_b <-  paste(output_dir, "plots/Density_plot_model_b.png", sep="")
inter_a=gen_thre(df, val=2, output_path_a)
inter_b=gen_thre(df, val=3, output_path_b)

output_barplot <- paste(output_dir, "plots/Bar_plot.png", sep="")
gen_bar_plot(df, 1,2,3, output_barplot)
output_box_a <- paste(output_dir, "plots/Box_plot_model_a.png", sep="")
output_box_b <-  paste(output_dir, "plots/Box_plot_model_b.png", sep="")
gen_box_plot(df, 2, output_box_a)
gen_box_plot(df, 3, output_box_b)

output_df_a <- paste(output_dir, "table/df_model_a.txt", sep="")
output_df_b <-  paste(output_dir, "table/df_model_b.txt", sep="")
df_model_a <- gen_class_df(df, inter_a, 2, output_df_a )
df_model_b <- gen_class_df(df, inter_b, 3, output_df_b)

output_plot_auc_a <- paste(output_dir, "plots/AUC_model_a.html", sep="")
output_plot_auc_b <-  paste(output_dir, "plots/AUC_model_b.html", sep="")

output_df_conf_a <- paste(output_dir, "table/confusion_matrix_model_a.txt", sep="")
output_df_conf_b <-  paste(output_dir, "table/confusion_matrix_model_b.txt", sep="")
conf_matrix<- gen_confusion_matrix(df_model_a, output_df_conf_a ) 
conf_matrix<- gen_confusion_matrix(df_model_b, output_df_conf_b )

output_plot_a <- paste(output_dir, "plots/ROC_model_a.png", sep="")
output_plot_b <-  paste(output_dir, "plots/ROC_model_b.png", sep="")
plot_roc_a <-simple_roc(df_model_a$caffeine_addiction, df_model_a$Classification_model,output_plot_a )
plot_roc_b <-simple_roc(df_model_b$caffeine_addiction, df_model_b$Classification_model,output_plot_b )

plot_a <- gen_plot_roc_auc(df_model_a)
htmlwidgets::saveWidget(as_widget(plot_a), output_plot_auc_a)

plot_b <-gen_plot_roc_auc(df_model_b)
htmlwidgets::saveWidget(as_widget(plot_b), output_plot_auc_b)


