"capgraph.deforceEqualApproachHead" <-
function(...) {
   capgraph(forceEqualApproachHead=FALSE, ...)
}
"capgraph.forceIgnoreApproachHead" <-
function(...) {
   capgraph(forceIgnoreApproachHead=TRUE, ...)
}

"capgraph" <-
function(h1=NULL, h4=NULL, datetime=NULL, culvert=NULL, approach=NULL,
         silent=TRUE, unlink=FALSE, showprogress=TRUE,
         savefile="TMP4capR_capgraph.RData",
         forceEqualApproachHead=NULL,
         forceIgnoreApproachHead=NULL) {

   n  <- length(h1); IX <- 1:n;
   if(n != length(h4)) {
      stop("\n*** headwater and tailwater vectors not of equal length ***");
   }

   if(is.null(datetime)) datetime <- 1:n;
   cache.h <- new.h();

   total.flows <- types <- abstypes <- vector(mode="numeric");
   road.flows <- culvert.flows <- total.flows;

   counter <- 0;
   if(showprogress) {
         catme(c("Processing", length(h1),
                 "values ('*' means from dynamic cache)..."));
   }
   for(i in IX) {
      if(showprogress) message(c(i), appendLF=FALSE);
      US.depth <- h1[i]; DS.depth <- h4[i];
      key <- paste(c(US.depth,":",DS.depth), sep="", collapse="");
      if(has.key(key, cache.h)) {
         cat(c("* "));
         computed.flow <- get.h(key, cache.h);
      } else {
         cat(c("  "));
         computed.flow <- computeFlow(culvert=culvert, approach=approach,
                                      h1=US.depth, h4=DS.depth, silent=silent,
                                      verbose=TRUE, plotapproach=FALSE,
                                      forceEqualApproachHead=forceEqualApproachHead,
                                      forceIgnoreApproachHead=forceIgnoreApproachHead);
      }
      if(! is.list(computed.flow)) {
         the.Qtotal <- the.Qroad <- the.Qculvert <- the.type <- NA;
      } else {
         the.Qtotal   <- computed.flow$Qtotal;
         the.Qroad    <- computed.flow$Qroad;
         the.Qculvert <- computed.flow$Qculvert;
         the.type     <- computed.flow$type;
         if(is.nan(the.Qculvert) | is.na(the.Qculvert)) {
            the.Qculvert <- NA;
            the.type     <- 0;
         }
         if(is.nan(the.Qtotal) | is.na(the.Qtotal)) the.Qtotal <- NA;
         if(is.nan(the.Qroad)  | is.na(the.Qroad)) the.Qroad <- NA;

      }
      total.flows[i]   <- the.Qtotal;
      culvert.flows[i] <- the.Qculvert;
      road.flows[i]    <- the.Qroad;
      abstypes[i]      <- ifelse(is.numeric(the.type), abs(the.type), 96);
      types[i]         <- the.type;
      set.h(key, computed.flow, cache.h);
   }
   if(showprogress) catme("\n");
   capgraph.RData <- list(ix=IX,
                          datetime=datetime,
                          h1=h1, h4=h4,
                          Qtotal=total.flows,
                          Qculvert=culvert.flows,
                          Qroad=road.flows,
                          Qtype=types, abstypes=abstypes);
   if(unlink) {
      message("Unlinking the savefile");
      try(unlink(savefile));
   }
   if(! file.exists(savefile)) {
      message("The savefile does not exist, testing whether to create one");
      if(! is.na(savefile)) {
        message(paste(c("savefile= ",savefile," now being written"),
                      collapse=""));
        try(save(capgraph.RData, file=savefile));
      } else {
        message("savefile=NA, so it was not written");
      }
   }
   return(capgraph.RData);
}

"plot.capgraph" <-
function(capgraph, culvert=NULL, plotfile=NULL, showtype=FALSE,
         showpoints=TRUE, ask=TRUE, index=NULL, minh=0) {

   if(is.null(culvert) || ! is.h(culvert)) {
     stop("culvert is NULL or not a culvert hash");
   }

   atypes <- c("1", "2", "3", "4", "5", "6");

   if(length(index) == 1) {
      index <- c(index, length(capgraph$ix));
   }
   if(is.null(index)) {
      datetime    <- capgraph$ix; # TODO: TIME SERIES
      h1          <- capgraph$h1;
      h4          <- capgraph$h4;
      total.flows <- capgraph$Qtotal;
      types       <- capgraph$types;
      abstypes    <- capgraph$abstypes;
   } else {
      datetime    <- capgraph$datetime[index];
      h1          <-       capgraph$h1[index];
      h4          <-       capgraph$h4[index];
      total.flows <-   capgraph$Qtotal[index];
      types       <-    capgraph$types[index];
      abstypes    <- capgraph$abstypes[index];
   }

   if(! is.null(plotfile)) ask <- FALSE;

   ifelse(is.null(datetime), my.xlab <- "TIME INDEX", my.xlab <- "TIME");
   if(! is.null(plotfile)) pdf(plotfile);
   ifelse(culvert$flowunits == "cubic feet per second",
          my.qunits <- ", IN FEET^3/SECOND",
          my.qunits <- ", IN METER^3/SECOND");
   my.ylab <- paste(c("DISCHARGE", my.qunits), sep="", collapse="");

   my.ymin <- 0.01;
   my.ymax <- 0.02;

   #catme("my.flows",total.flows);
   my.flows <- total.flows[! is.na(total.flows)];
   #catme("my.flows",my.flows);
   if(length(my.flows) != 0) {
      my.ymin <- min(my.flows[my.flows >= 0]);
      my.ymax <- max(my.flows);
   }
   #catme("ymin:",my.ymin);
   #catme("ymax:",my.ymax);
   #catme("xmin:", datetime[1]);
   my.ymin <- 10^( log10(my.ymin) - 0.05);
   my.ymax <- 10^( log10(my.ymax) + 0.05);

   plot(datetime, total.flows, type="l",
        ylim=c(my.ymin, my.ymax),
        xlab=my.xlab, ylab=my.ylab, tcl=0.5);
   legend(datetime[1],
          my.ymax, c("USGS type 1 flow", "USGS type 2 flow",
                     "USGS type 3 flow", "USGS type 4 flow",
                     "USGS type 5 flow", "USGS type 6 flow",
                     "USGS 2-sec SAC flow"),
          pch=16, col=c(1:6,8), cex=1, bty="n", pt.cex=0.75);
   for(i in 1:length(datetime)) {
     if(showtype)   points(datetime[i],total.flows[i],
                           col=abstypes[i], pch=atypes[types[i]]);
     if(showpoints) points(datetime[i],total.flows[i],
                           col=abstypes[i], pch=16, cex=1);
   }

   ifelse(culvert$lengthunits == "feet",
          my.lunits <- ", IN FEET",
          my.lunits <- ", IN METERS");
   my.ylab <- paste(c("HEAD- AND TAIL-WATER GAGE HEIGHT", my.lunits),
                    sep="", collapse="");
   if(ask) readline("Hit <Return> to see gage-height plot ");
   plot(c(datetime[1], datetime[length(datetime)]),
        c(minh, max(h1,h4)),
        xlab=my.xlab, ylab=my.ylab, type="n", tcl=0.5);
   lines(datetime, h1);
   lines(datetime, h4, col=2);
   if(! is.null(plotfile)) dev.off();
   if(ask) readline("Hit <Return> to continue ");
}


"write.capgraph" <-
function(capgraph, culvert=NULL, approach=NULL,
         index=NULL, sep=",", ...) {
   if(is.null(culvert) || ! is.h(culvert)) {
     stop("culvert is NULL or not a culvert hash");
   }
   if(is.null(approach) || ! is.h(approach)) {
     stop("approach is NULL or not an approach hash");
   }

   # double && needed to ensure that both are evaluated
   if(is.h(approach) && has.key("time.series.out", approach)) {
      outfile <- get.h("time.series.out", approach);
   }
   if(is.null(outfile)) outfile <- "";

   if(length(index) == 1) {
      index <- c(index, length(capgraph$ix));
   }
   if(! is.null(index)) {
      capgraph <- as.list(as.data.frame(capgraph)[index,]);
   }

   write.table(capgraph, file=outfile, sep=sep,
               quote=FALSE,
               row.names=FALSE, ...);
}



"demo.capgraph" <-
function(road=TRUE, ...) {
  US <- c(1,   1.5, 4, 5,   5,   6,   7, 9, 12, 14, 6, 7, 4, 3.5, 3.5,   2, 1);
  DS <- c(0.5, 1.1, 2, 2, 2.5, 2.3, 4.5, 5,  3,  5, 2, 1, 3, 2.5, 2.2, 0.5, 0.7);

  X <- c(0, 200, 230, 430);
  Y <- c(100, 0,   0, 100);
  my.approach <- setApproach(X=X, Y=Y);

  bvals <- c(8.5, 9, 10, 12, 15);
  elevs <- sapply(bvals, function(x) { return((x - 8.5)^2) });
  if(road) {
    my.road <- setRoad(crown.elev=8.5, road.width=50,
                       crest.lengths=data.frame(b=bvals, elev=elevs));
  } else {
    my.road <- NULL;
  }
  my.culvert <- setCulvert(type="circle",
                           material="concrete",
                           diameter=4,
                           rounding=0.008,
                           nvalue=0.015,
                           L=80,
                           slope=0.001,
                           road=my.road);

  flows <- capgraph(h1=US, h4=DS, culvert=my.culvert,
                    approach=my.approach, ...);
  plot.capgraph(flows, culvert=my.culvert);
  write.capgraph(flows, culvert=my.culvert, approach=my.approach);
}



"capgraphSystem" <-
function(h1=NULL, h4=NULL, datetime=NULL, culverts=NULL, approach=NULL,
         silent=TRUE, unlink=FALSE, showprogress=TRUE,
         savefile="TMP4capR_capgraph.RData",
         forceEqualApproachHead=NULL,
         forceIgnoreApproachHead=NULL) {

   n  <- length(h1); IX <- 1:n;
   if(n != length(h4)) {
      stop("\n*** headwater and tailwater vectors not of equal length ***");
   }

   if(is.null(datetime)) datetime <- 1:n;
   cache.h <- new.h();

   total.flows <- vector(mode="numeric");

   counter <- 0;
   if(showprogress) {
         catme(c("Processing", length(h1),
                 "values ('*' means from dynamic cache)..."));
   }
   for(i in IX) {
      if(showprogress) message(c(i), appendLF=FALSE);
      US.depth <- h1[i]; DS.depth <- h4[i];
      key <- paste(c(US.depth,":",DS.depth), sep="", collapse="");
      if(has.key(key, cache.h)) {
         cat(c("* "));
         computed.flow <- get.h(key, cache.h);
      } else {
         cat(c("  "));
         computed.flow <- computeFlowSystem(culverts=culverts, approach=approach,
                                      h1=US.depth, h4=DS.depth, silent=silent,
                                      verbose=TRUE, plotapproach=FALSE,
                                      forceEqualApproachHead=forceEqualApproachHead,
                                      forceIgnoreApproachHead=forceIgnoreApproachHead);
      }
      if(! is.list(computed.flow)) {
         the.Qtotal <- NA;
      } else {
         the.Qtotal   <- computed.flow$Qtotal;
         if(is.nan(the.Qtotal) | is.na(the.Qtotal)) the.Qtotal <- NA;
      }
      total.flows[i]   <- the.Qtotal;
      set.h(key, computed.flow, cache.h);
   }
   if(showprogress) catme("\n");
   capgraph.RData <- list(ix=IX,
                          datetime=datetime,
                          h1=h1, h4=h4,
                          Qtotal=total.flows);
   if(unlink) {
      message("Unlinking the savefile");
      try(unlink(savefile));
   }
   if(! file.exists(savefile)) {
      message("The savefile does not exist, testing whether to create one");
      if(! is.na(savefile)) {
        message(paste(c("savefile= ",savefile," now being written"),
                      collapse=""));
        try(save(capgraph.RData, file=savefile));
      } else {
        message("savefile=NA, so it was not written");
      }
   }
   return(capgraph.RData);
}
