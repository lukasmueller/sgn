#formats and combines phenotype (of a single trait)
#and genotype datasets of multiple
#populations

options(echo = FALSE)

library(stats)
library(stringr)
library(imputation)
library(plyr)
library(nlme)


allArgs <- commandArgs()

inFile <- grep("input_files",
               allArgs,
               ignore.case = TRUE,
               perl = TRUE,
               value = TRUE
               )

outFile <- grep("output_files",
                allArgs,
                ignore.case = TRUE,
                perl = TRUE,
                value = TRUE
                )

outFiles <- scan(outFile,
                 what = "character"
                 )
print(outFiles)

combinedGenoFile <- grep("genotype_data",
                         outFiles,
                         ignore.case = TRUE,
                         fixed = FALSE,
                         value = TRUE
                         )

combinedPhenoFile <- grep("phenotype_data",
                          outFiles,
                          ignore.case = TRUE,
                          fixed = FALSE,
                          value = TRUE
                          )

inFiles <- scan(inFile,
                what = "character"
                )
print(inFiles)

traitFile <- grep("trait_",
                  inFiles,
                  ignore.case = TRUE,
                  fixed = FALSE,
                  value = TRUE
                  )

trait <- scan(traitFile,
              what = "character",
              )
print(trait)

traitInfo<-strsplit(trait, "\t");
traitId<-traitInfo[[1]]
traitName<-traitInfo[[2]]

#extract trait phenotype data from all populations
#and combine them into one dataset

allPhenoFiles <- grep("phenotype_data",
                  inFiles,
                  ignore.case = TRUE,
                  fixed = FALSE,
                  value = TRUE
                  )
print(allPhenoFiles)

allGenoFiles <- grep("genotype_data",
                  inFiles,
                  ignore.case = TRUE,
                  fixed = FALSE,
                  value = TRUE
                  )


print(allGenoFiles)

popsPhenoSize     <- length(allPhenoFiles)
popsGenoSize      <- length(allGenoFiles)
popIds            <- c()
combinedPhenoPops <- c()

for (popPhenoNum in 1:popsPhenoSize)
  {
    popId <- str_extract(allPhenoFiles[[popPhenoNum]], "\\d+")
    popIds <- append(popIds, popId)

    print(popId)
    phenoData <- read.table(allPhenoFiles[[popPhenoNum]],
                            header = TRUE,
                            row.names = 1,
                            sep = "\t",
                            na.strings = c("NA", " ", "--", "-", "."),
                            dec = "."
                           )


    phenoTrait <- subset(phenoData,
                         select = c("object_name", "stock_id", "design", "block", "replicate", traitName)
                         )
  
    experimentalDesign <- phenoTrait[2, 'design']
    
    if (is.na(experimentalDesign) == TRUE) {experimentalDesign <- c('No Design')}

    if (experimentalDesign == 'augmented') {

    bloLevels  <- length(unique(phenoTrait$blocks))
    replicates <- unique(phenoTrait$replicates)
    allGenos   <- phenoTrait$object_name
    response   <- phenoTrait[, traitName]
         
    allGenosFreq <- data.frame(table(phenoTrait$object_name))

    checkGenos <- subset(allGenosFreq, Freq == bloLevels)
    unRepGenos <- subset(allGenosFreq, Freq == 1)
    cG         <- checkGenos[, 1]
    uRG        <- unRepGenos[, 1]
    
    checkGenos <- data.frame(phenoTrait[phenoTrait$object_name %in% cG, ]) 
    bloMeans   <- data.frame(tapply(checkGenos[, traitName], checkGenos[, "blocks"], mean))
    checkMeans <- data.frame(tapply(checkGenos[, traitName], checkGenos[, "object_name"], mean))
    checkMeans <- subset(checkMeans, is.na(checkMeans)==FALSE)
     
    gBloMean   <- mean(checkGenos[, traitName])
    colnames(bloMeans)   <- c("mean")
    colnames(checkMeans) <- c("mean")
      
    adjMeans <- data.matrix(checkMeans)
  
    adjGenoMeans <- function(x) {

      xG <- x[[1]]
      mr <- c()
    
      if(length(grep(xG, cG)) != 1) {
     
        bm <- as.numeric(bloMeans[x[[4]], ])       
        rV <- as.numeric(x[[6]])       
        m  <-  rV - bm + gBloMean 
        mr <- data.frame(xG, "mean"=m)
        rownames(mr) <- mr[, 1]
        mr[, 1] <- NULL
        mr <- data.matrix(mr)
    
      }

      return (mr)
        
    }
  
    nr <- nrow(phenoTrait)
    for (j in 1:nr ) {
    
      mr       <- adjGenoMeans(phenoTrait[j, ]) 
      adjMeans <- rbind(adjMeans, mr)
           
    }

    adjMeans <- round(adjMeans, digits=2)
      
    phenoTrait <- data.frame(adjMeans)
    formattedPhenoData[, trait] <- phenoTrait
 
  } else if (experimentalDesign == 'alpha lattice') {
   # trait <- i
    alphaData <-  phenoTrait 
      
    colnames(alphaData)[2] <- "genotypes"
    colnames(alphaData)[5] <- "trait"
     
    ff <- traitName ~ 0 + genotypes
      
    model <- lme(ff,
                 data = alphaData,
                 random = ~1|replicates/blocks,
                 method = "REML",
                 na.action = na.omit
                 )
   
    adjMeans <- data.matrix(fixed.effects(model))
    colnames(adjMeans) <- traitName
      
    nn <- gsub('genotypes', '', rownames(adjMeans))
    rownames(adjMeans) <- nn
    adjMeans <- round(adjMeans, digits = 2)

    phenoTrait <- data.frame(adjMeans)
    formattedPhenoData[, i] <- phenoTrait
  
  } else {

    phenoTrait <- subset(phenoData,
                         select = c("object_name", "stock_id", traitName)
                         )
    
    if (sum(is.na(phenoTrait)) > 0)
      {
        print("sum of pheno missing values")
        print(sum(is.na(phenoTrait)))

        #fill in for missing data with mean value
        phenoTrait[, traitName]  <- replace (phenoTrait[, traitName],
                                             is.na(phenoTrait[, traitName]),
                                             mean(phenoTrait[, traitName], na.rm =TRUE)
                                            )
        
       #calculate mean of reps/plots of the same accession and
       #create new df with the accession means
        phenoTrait$stock_id <- NULL
        phenoTrait   <- phenoTrait[order(row.names(phenoTrait)), ]
   
        print('phenotyped lines before averaging')
        print(length(row.names(phenoTrait)))
        
        phenoTrait<-ddply(phenoTrait, "object_name", colwise(mean))
        
        print('phenotyped lines after averaging')
        print(length(row.names(phenoTrait)))
   
        row.names(phenoTrait) <- phenoTrait[, 1]
        phenoTrait[, 1] <- NULL

        phenoTrait <- round(phenoTrait, digits = 2)

      } else {
      print ('No missing data')
      phenoTrait$stock_id <- NULL
      phenoTrait   <- phenoTrait[order(row.names(phenoTrait)), ]
   
      print('phenotyped lines before averaging')
      print(length(row.names(phenoTrait)))
      
      phenoTrait<-ddply(phenoTrait, "object_name", colwise(mean))
      
      print('phenotyped lines after averaging')
      print(length(row.names(phenoTrait)))

      row.names(phenoTrait) <- phenoTrait[, 1]
      phenoTrait[, 1] <- NULL

      phenoTrait <- round(phenoTrait, digits = 2)

    }
  }

    
    newTraitName = paste(traitName, popId, sep = "_")
    colnames(phenoTrait)[1] <- newTraitName

    if (popPhenoNum == 1 )
      {
        print('no need to combine, yet')       
        combinedPhenoPops <- phenoTrait
        
      } else {
      print('combining...') 
      combinedPhenoPops <- merge(combinedPhenoPops, phenoTrait,
                            by = 0,
                            all=TRUE,
                            )

      rownames(combinedPhenoPops) <- combinedPhenoPops[, 1]
      combinedPhenoPops$Row.names <- NULL
      
    }   
}

#fill in missing data in combined phenotype dataset
#using row means
naIndices <- which(is.na(combinedPhenoPops), arr.ind=TRUE)
combinedPhenoPops <- as.matrix(combinedPhenoPops)
combinedPhenoPops[naIndices] <- rowMeans(combinedPhenoPops, na.rm=TRUE)[naIndices[,1]]
combinedPhenoPops <- as.data.frame(combinedPhenoPops)

message("combined total number of stocks in phenotype dataset (before averaging): ", length(rownames(combinedPhenoPops)))

combinedPhenoPops$Average<-round(apply(combinedPhenoPops,
                                       1,
                                       function(x)
                                       { mean(x) }
                                       ),
                                 digits = 2
                                 )

markersList      <- c()
combinedGenoPops <- c()

for (popGenoNum in 1:popsGenoSize)
  {
    popId <- str_extract(allGenoFiles[[popGenoNum]], "\\d+")
    popIds <- append(popIds, popId)

    print(popId)
    genoData <- read.table(allGenoFiles[[popGenoNum]],
                            header = TRUE,
                            row.names = 1,
                            sep = "\t",
                            na.strings = c("NA", " ", "--", "-"),
                            dec = "."
                           )
    
    popMarkers <- colnames(genoData)
    message("No of markers from population ", popId, ": ", length(popMarkers))
    #print(popMarkers)
  
    if (sum(is.na(genoData)) > 0)
      {
        print("sum of geno missing values")
        print(sum(is.na(genoData)))

        #impute missing genotypes
        genoData <-kNNImpute(genoData, 10)
        genoData <-as.data.frame(genoData)

        #extract columns with imputed values
        genoData <- subset(genoData,
                                select = grep("^x", names(genoData))
                                )

        #remove prefix 'x.' from imputed columns
        print(genoData[1:50, 1:4])
        names(genoData) <- sub("x.", "", names(genoData))

        genoData <- round(genoData, digits = 0)
        message("total number of stocks for pop ", popId,": ", length(rownames(genoData)))
      }

    if (popGenoNum == 1 )
      {
        print('no need to combine, yet')       
        combinedGenoPops <- genoData
        
      } else {
        print('combining genotype datasets...') 
        combinedGenoPops <-rbind(combinedGenoPops, genoData)
      }   
    
 
  }
message("combined total number of stocks in genotype dataset: ", length(rownames(combinedGenoPops)))
#discard duplicate clones
combinedGenoPops <- unique(combinedGenoPops)
message("combined unique number of stocks in genotype dataset: ", length(rownames(combinedGenoPops)))

message("writing data into files...")
if(length(combinedPhenoFile) != 0 )
  {
      write.table(combinedPhenoPops,
                  file = combinedPhenoFile,
                  sep = "\t",
                  quote = FALSE,
                  col.names = NA,
                  )
  }

if(length(combinedGenoFile) != 0 )
  {
      write.table(combinedGenoPops,
                  file = combinedGenoFile,
                  sep = "\t",
                  quote = FALSE,
                  col.names = NA,
                  )
  }

q(save = "no", runLast = FALSE)
