param (
    [Parameter(Mandatory=$true)][string]$apk,
    [Parameter(Mandatory=$true)][string]$libdir,
    [Parameter(Mandatory=$true)][string]$androidSDK
)

function New-TemporaryDirectory {
    $parent = [System.IO.Path]::GetTempPath()
    [string] $name = [System.Guid]::NewGuid()
    New-Item -ItemType Directory -Path (Join-Path $parent $name)
}

if (-Not (Test-Path env:JAVA_HOME)) {
    Write-Output "env:JAVA_HOME must be set"
    exit 1
}


#this script does the following:
# * generate a key if it does not yet exist
# * unpack the APK
# * unsign the unpacked apk
# * place the shared lib in the unpacked APK
# * repack the APK and resign it with the key

#set up keys
$workdir = pwd
$keyfile = Join-Path $workdir "\my-release-key.keystore"
if (-not(Test-Path -Path $keyfile -PathType Leaf)) {
    keytool -genkey -v -keystore $keyfile -alias alias_name -keyalg RSA -keysize 2048 -validity 10000
}

pushd

#make tmp folder
$tmpdir = New-TemporaryDirectory
mkdir $tmpdir/unzipped | Out-Null

#copy apk over as zip
$apkname = (Get-ChildItem $apk).BaseName
$apkzipname = $apkname + '.zip'
Copy-Item $apk $tmpdir'/'$apkzipname
Set-Location $tmpdir/unzipped

#unpack APK to tmpdir
echo "unpacking to " + $tmpdir/unzipped
7z x $tmpdir\$apkzipname | Out-Null

#modify APK
mkdir .\assets\openxr\1\api_layers\implicit.d | Out-Null
cp $libdir/manifest.json .\assets\openxr\1\api_layers\implicit.d
cp $libdir/librnr.so .\assets\openxr\1\api_layers\implicit.d
Remove-Item -Path META-INF\*.*
$newzipname = $apkname + '.new.zip'

#repack APK and align it
echo "repacking... (this may take a while)"
7z a -m0=Copy -tzip $newzipname * resources.arsc | Out-Null
mv $newzipname ..
cd ..
$newapkname = $apkname + '.new.apk'
mv $newzipname $newapkname
$buildtools = (dir $androidSDK\build-tools\).Name
$alignedapkname = $apkname + '.new.aligned.apk'
echo $androidSDK\build-tools\$buildtools\zipalign
echo "aligned APK: " + $alignedapkname

#according to https://stackoverflow.com/questions/10930331/how-to-sign-an-already-compiled-apk
#the signing process is a 4 step process where step 1 is generating the key:

#step 2 align the apk for compression
zipalign -p -v 4 $newapkname $alignedapkname

#step 3 sign the apk
apksigner sign --ks-key-alias alias_name --ks $keyfile $alignedapkname
#verify the signature
apksigner verify $alignedapkname
echo "verified?"
zipalign -vc 4 "$alignedapkname"
echo "correctly aligned?"

adb install $alignedapkname

popd

rm -Recurse $tmpdir

#step 4
#Invoke-Expression "& `"$androidSDK/jarsigner.exe`" -verbose -sigalg SHA256withRSA -keystore $keyfile $alignedapkname alias_name"
#verify step 4
#jarsigner -verify -verbose $alignedapkname