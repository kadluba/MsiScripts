if (test-path .\SignedSetupv1.msi.bak) {
	mv -force .\SignedSetupv1.msi.bak .\SignedSetupv1.msi
}
if (test-path .\WixLanguage.msi.bak) {
	mv -force .\WixLanguage.msi.bak .\WixLanguage.msi
}
#rm -force *.csv
#rm -force SignedSetupv1.msi\*
#rm -force WixLanguage.msi\*
rm ${env:temp}\msi*.log -force
