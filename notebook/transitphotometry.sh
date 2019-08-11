#!/bin/bash

if [ $# -lt 1 ]; then
    echo "Usage: $0 <event>" 
	exit
fi

event=$1
eventinfo=$(awk '$1~"^'$event'$"{print $1,$2,$3,$4,$5}' eventlist)
if [ ! -n "$eventinfo" ] ;then
        echo EVENT $event NOT FOUND!
        exit
fi

RA=$(echo $eventinfo | awk '{print $2}')
DEC=$(echo $eventinfo | awk '{print $3}')
ref=$(echo $eventinfo | awk '{print $4}')
Vmag=$(echo $eventinfo | awk '{print $5}')
echo $event FOUND!
echo RA=$RA,DEC=$DEC,reference image=$ref,Vmag=$Vmag

curdir=$(pwd)
imagedir=($curdir/event/$event)


mkdir -p event/$event/data/catalog
mkdir -p event/$event/data/comparison
mkdir -p event/$event/data/pho_cat
mkdir -p event/$event/data/pho_cat_sim
mkdir -p event/$event/data/cat_rel_flux
mkdir -p event/$event/data/com_rel_flux
mkdir -p event/$event/data/com_judge
mkdir -p event/$event/data/pho_com
mkdir -p event/$event/data/pho_com_sim
mkdir -p event/$event/data/coordinate_cat
mkdir -p event/$event/data/coordinate_com
mkdir -p event/$event/data/ligcur_com
mkdir -p event/$event/data/ligcur_cat

cd $imagedir
ls -F *.fits > imagelist
cd $curdir
python region.py $curdir $imagedir $curdir/event/$event/data/catalog $curdir/event/$event/data/comparison $RA $DEC $Vmag $ref


#choose the star B magnitude limit you want to do the photometry#
#######################################################################################################################
#exit
#######################################################################################################################

cd $curdir/event/$event/data/catalog
while read im ;do
        if [ -e ${im%.*}_blend_new ] ; then
                rm ${im%.*}_blend_new
        fi
        echo "#STAR_Number      RA      DEC     X_IMAGE Y_IMAGE Jmag    Kmag    Bmag    Vmag#" > $curdir/event/$event/data/catalog/${im%.*}_blend_new
        awk -v Vmag=$Vmag -v RA=$RA -v DEC=$DEC ' NR>1 {printf("%s     %.4f    %.4f    %.4f    %.4f    %.3f    %.3f    %.3f    %.3f\n",$1,$2,$3,$4,$5,$6,$7,$8,$9)}' $curdir/event/$event/data/catalog/${im%.*}_blend >> $curdir/event/$event/data/catalog/${im%.*}_blend_new
done <$curdir/event/$event/imagelist


cd $curdir/event/$event/data/comparison
while read im ;do
	if [ -e ${im%.*}_com_new ] ; then	
		rm ${im%.*}_com_new
	fi 
	echo "#STAR_Number	RA	DEC	X_IMAGE	Y_IMAGE	Jmag	Kmag	Bmag	Vmag#" > $curdir/event/$event/data/comparison/${im%.*}_com_new
	awk -v Vmag=$Vmag -v RA=$RA -v DEC=$DEC ' NR>1 && ($9-Vmag)*($9-Vmag)<=6 && (($2-RA)*($2-RA)>0.0025 || ($3-DEC)*($3-DEC)>0.0025){printf("%s	%.4f	%.4f	%.4f	%.4f	%.3f	%.3f	%.3f	%.3f\n",$1,$2,$3,$4,$5,$6,$7,$8,$9)}' $curdir/event/$event/data/comparison/${im%.*}_com >> $curdir/event/$event/data/comparison/${im%.*}_com_new
done <$curdir/event/$event/imagelist

echo ===============================================
echo      blending and comparison stars fiphot photometry
echo ===============================================
echo RAW PHOTOMETRY.
while read im ;do
	if [ -e $curdir/event/$event/data/pho_cat/${im%.*}.cat ] ; then
		echo $im photometry has already finished !
		continue ;
	else
		echo $im DONE!
		fiphot --input $curdir/event/$event/$im --input-list $curdir/event/$event/data/catalog/${im%.*}_blend_new --col-id 1 --col-xy 4,5 --col-mag 9 --gain 1 --aperture 10:18:9 --sky-fit 'median, sigma=3, iterations=4' --disjoint-radius 2 --format "ISXY,MmFfXxYyBb" --nan-string 'NaN' --comment '--comment' --output  $curdir/event/$event/data/pho_cat/${im%.*}.cat --serial $im
		fiphot --input $curdir/event/$event/$im --input-list $curdir/event/$event/data/comparison/${im%.*}_com_new --col-id 1 --col-xy 4,5 --col-mag 9 --gain 1 --aperture 10:18:9 --sky-fit 'median, sigma=3, iterations=4' --disjoint-radius 2 --format "ISXY,MmFfXxYyBb" --nan-string 'NaN' --comment '--comment' --output  $curdir/event/$event/data/pho_com/${im%.*}.com --serial $im
	fi
done <$curdir/event/$event/imagelist

echo ======================
echo RAW PHOTOMETRY successfully
echo ======================

for number in $( seq 1 3 );
do
python coordinate_calibration.py $curdir/event/$event/data/pho_cat $curdir/event/$event/data/coordinate_cat $curdir/event/$event/data/pho_com $curdir/event/$event/data/coordinate_com
while read im ;do
	fiphot --input $curdir/event/$event/$im --input-list $curdir/event/$event/data/coordinate_cat/${im%.*}_blend --col-id 1 --col-xy 2,3 --col-mag 4 --gain 1 --aperture 10:18:9 --sky-fit 'median, sigma=3, iterations=4' --disjoint-radius 2 --format "ISXY,MmFfXxYyBb" --nan-string 'NaN' --comment '--comment' --output  $curdir/event/$event/data/pho_cat/${im%.*}.cat --serial $im
	fiphot --input $curdir/event/$event/$im --input-list $curdir/event/$event/data/coordinate_com/${im%.*}_com --col-id 1 --col-xy 2,3 --col-mag 4 --gain 1 --aperture 10:18:9 --sky-fit 'median, sigma=3, iterations=4' --disjoint-radius 2 --format "ISXY,MmFfXxYyBb" --nan-string 'NaN' --comment '--comment' --output  $curdir/event/$event/data/pho_com/${im%.*}.com --serial $im
done <$curdir/event/$event/imagelist
echo $number PHOTOMETRY FINISHED.
done	
echo ==============
echo fiphot successfully
echo ==============

exit
cd $curdir
python simple.py $curdir/event/$event/data/pho_cat $curdir/event/$event/data/pho_cat_sim
python simple.py $curdir/event/$event/data/pho_com $curdir/event/$event/data/pho_com_sim


while read im ; do
	python calibration.py  $curdir/event/$event/data/pho_com_sim $curdir/event/$event/data/pho_cat_sim ${ref%.*}.com ${im%.*}.com
done <$curdir/event/$event/imagelist



INDIR=$curdir/event/$event/data/pho_com_sim
cd $curdir/event/$event/data/com_judge
while read im ;do
	cat $INDIR/${im%.*}.com;
done <$curdir/event/$event/imagelist | grcollect - --col-base 1 --extension lc
oldext="lc"
newext=""
dir=$curdir/event/$event/data/com_judge
for file in $(ls $dir | grep .$oldext)
    do
    name=$(ls $file | cut -d. -f1)
    mv $file ${name}
done

ls -F $curdir/event/$event/data/com_judge > $curdir/event/$event/list_ref
wrong_star_count=0
comparison_stars_number=0
while read line; do
		let comparison_stars_number+=1
		mean=$(awk 'BEGIN{n=0;sum=0}{sum+=$5; n++}END{print sum/n}' $curdir/event/$event/data/com_judge/$line)
		value=$(awk -v mean=$mean 'BEGIN{n=0;sum=0}{sum+=($5-mean)*($5-mean); n++}END{print sqrt(sum/n),4*sqrt(sum/n) }' $curdir/event/$event/data/com_judge/$line) #find sigma
		sigma=$(echo $value | awk '{print $1}')
		sigma2=$(echo $value | awk '{print $2}')
		echo $line mag_sigma=$sigma
		if [[ ! $sigma =~ "nan" ]]
		then
			#if [ $(echo "$sigma = 0 " | bc) -eq 1 ] ; then 
			#	let wrong_star_count+=1
			#	cd $curdir/event/$event/data/pho_com_sim                        
                        #        echo $line >> $curdir/event/$event/badrefstar
			#fi
			if [ $(echo "$sigma > 0.003" | bc) -eq 1 ] ; then
				let wrong_star_count+=1
				cd $curdir/event/$event/data/pho_com_sim			
				echo $line >> $curdir/event/$event/badrefstar
				#while read im ;do
					#name=$(awk 'NR=='$comparison_stars_number'{print $1}' $curdir/transit/$event/data/pho_com_sim/${im%.*}.com)
					#perl -i -pne 's/'$name'/'#$name'/' $curdir/pho_com_sim/${im%.*}.com               
				#done <$curdir/transit/$event/imagelist
			fi
		else
			let wrong_star_count+=1
			cd $curdir/event/$event/data/pho_com_sim			
			while read im ;do
				name=$(awk 'NR=='$comparison_stars_number'{print $1}' $curdir/event/$event/data/pho_com_sim/${im%.*}.com)
				perl -i -pne 's/'$name'/'#$name'/' $curdir/event/$event/data/pho_com_sim/$im               
			done <$curdir/event/$event/imagelist
		fi
done < $curdir/event/$event/list_ref


##############################################################################
if [ ! -e $curdir/event/$event/badrefstar ]; then
	echo all comparison stars are ok! 
else
	if [ ! -e $curdir/event/$event/badref ] ; then
		cp $curdir/event/$event/badrefstar $curdir/event/$event/badref
		rm $curdir/event/$event/badrefstar
		echo USING THE DEFAULT BAD REFERENCE STARS CATALOG!
	else
		echo USING THE MODIFIED BAD REFERENCE STARS CATALOG!
	fi
fi
##############################################################################


if [ -e $curdir/event/$event/badref ] ; then
	while read star ; do
		while read imnu ; do
			perl -i -pne 's/'$star'/'#$star'/' $curdir/event/$event/data/pho_com_sim/${imnu%.*}.com  
		done <$curdir/event/$event/imagelist
	done <$curdir/event/$event/badref
fi 

if [ $(echo "$wrong_star_count == $comparison_stars_number" | bc) -eq 1 ] ; then
	echo NO ENOUGH COMPARISON STARS,PLEASE CHANGE THE LIMIT
	exit
fi


#get relative flux light curves of comparison stars#
cd $curdir
python com_flux-rel_flux.py $curdir/event/$event/data/pho_com_sim $curdir/event/$event/data/com_rel_flux
INDIR=$curdir/event/$event/data/com_rel_flux
cd $curdir/event/$event/data/ligcur_com

while read im ;do
	cat $INDIR/${im%.*}.com;
done <$curdir/event/$event/imagelist | grcollect - --col-base 1 --extension lc

#get relative flux light curves of target stars#
cd $curdir
python cat_flux-rel_flux.py $curdir/event/$event/data/pho_com_sim $curdir/event/$event/data/pho_cat_sim $curdir/event/$event/data/cat_rel_flux 
INDIR=$curdir/event/$event/data/cat_rel_flux
cd $curdir/event/$event/data/ligcur_cat

while read im ;do
	cat $INDIR/${im%.*}.cat;
done <$curdir/event/$event/imagelist | grcollect - --col-base 1 --extension lc

#add time and airmass into the light curve files#
cd $curdir/event/$event/data/ligcur_cat
ls *.lc > $curdir/event/$event/blendlcs
rm $curdir/event/$event/data/ligcur_cat/*_fin
cd $curdir/event/$event/data/ligcur_com
ls *.lc > $curdir/event/$event/comparlcs
rm $curdir/event/$event/data/ligcur_com/*_fin
while read star; do 
	while read im; do
		image=$(echo $im | awk '{print $2}')
		x=$(echo $im | awk '{print $3}')
		y=$(echo $im | awk '{print $4}')
		mag=$(echo $im | awk '{print $5}')
		magerr=$(echo $im | awk '{print $6}')
		flux=$(echo $im | awk '{print $7}')
		fluxerr=$(echo $im | awk '{print $8}')
		p=$(echo $(gethead MJD-OBS EXPTIME AIRMASS $curdir/event/$event/$image) | awk '{printf("%12.6f %f",$1+0.5*$2/3600.0/24.0,$3)}')
		time=$(echo $p | awk '{print $1}')
		airmass=$(echo $p | awk '{print $2}')
		echo $x	$y	$mag	$magerr	$flux	$fluxerr	$time	$airmass >> $curdir/event/$event/data/ligcur_cat/${star}_fin
	done < $curdir/event/$event/data/ligcur_cat/$star

done < $curdir/event/$event/blendlcs

while read star; do 
        while read im; do
                image=$(echo $im | awk '{print $2}')
                x=$(echo $im | awk '{print $3}')
                y=$(echo $im | awk '{print $4}')
                mag=$(echo $im | awk '{print $5}')
                magerr=$(echo $im | awk '{print $6}')
                flux=$(echo $im | awk '{print $7}')
                fluxerr=$(echo $im | awk '{print $8}')
                p=$(echo $(gethead MJD-OBS EXPTIME AIRMASS $curdir/event/$event/$image) | awk '{printf("%12.6f %f",$1+0.5*$2/3600.0/24.0,$3)}')
                time=$(echo $p | awk '{print $1}')
                airmass=$(echo $p | awk '{print $2}')
                echo $x $y      $mag    $magerr $flux   $fluxerr        $time   $airmass >> $curdir/event/$event/data/ligcur_com/${star}_fin
        done < $curdir/event/$event/data/ligcur_com/$star

done < $curdir/event/$event/comparlcs


exit
