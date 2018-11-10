########################################################
#                                                      #
#     Generic Makefile for distributing LÖVE games     #
#                                                      #
########################################################


# The name of the game
NAME=FiveSeconds

# The directory where you want to put your files. It should be a subdirectory of
# Dropbox/Public.
DEST=~/Dropbox/Public/LudumDare27

# All the files/directories used in the game
FILES=Makefile main.lua conf.lua Images Sounds

#
LOVEWIN32=dist/love-0.8.0-win-x86

###########

DESTNAME=${DEST}/${NAME}

.PHONY: distribute love src windows macosx

distribute: love src windows macosx
	@echo "# Public links"
	@echo
	@mkdir -p ${DEST}
# .love
	@echo "All platforms (.love file)"
	@dropbox puburl ${DESTNAME}.love
	@echo
# Windows
	@echo "Windows (standalone)"
	@dropbox puburl ${DESTNAME}-windows.zip
	@echo
# Mac OS X
	@echo "Mac OS X (standalone)"
	@dropbox puburl ${DESTNAME}-macosx.zip
	@echo
# Source
	@echo "Source"
	@dropbox puburl ${DESTNAME}-src.zip
	@echo

love:
	@echo "# Building the .love file"
	rm -f dist/${NAME}.love
	zip -9 -q -r dist/${NAME}.love ${FILES}
	cp dist/${NAME}.love ${DESTNAME}.love
	@echo

src:
	@echo "# Building the source file"
	rm -f dist/${NAME}-src.zip
	zip -9 -q -r dist/${NAME}-src.zip ${FILES}
	cp dist/${NAME}-src.zip ${DESTNAME}-src.zip
	@echo

windows: love
	@echo "# Building the Windows executable"
	rm -f ${LOVEWIN32}/${NAME}.exe dist/${NAME}-windows.zip
	cat ${LOVEWIN32}/love.exe dist/${NAME}.love > ${LOVEWIN32}/${NAME}.exe
	cd ${LOVEWIN32}; zip -9 -q -r ../${NAME}-windows.zip\
        {SDL.dll,OpenAL32.dll,${NAME}.exe,license.txt,DevIL.dll}
	cp dist/${NAME}-windows.zip ${DESTNAME}-windows.zip
	@echo

macosx: love
	@echo "# Building the Mac OS X executable"
	rm -f dist/${NAME}.app/Contents/Resources/${NAME}.love dist/${NAME}-macosx.zip
	cp dist/${NAME}.love dist/${NAME}.app/Contents/Resources/
	cd dist; zip -9 -q -r ${NAME}-macosx.zip ${NAME}.app
	cp dist/${NAME}-macosx.zip ${DESTNAME}-macosx.zip
	@echo
