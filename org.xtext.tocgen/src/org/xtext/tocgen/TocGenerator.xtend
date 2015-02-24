/*******************************************************************************
 * Copyright (c) 2015 itemis AG (http://www.itemis.eu) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *******************************************************************************/
package org.xtext.tocgen

import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import java.io.File

@FinalFieldsConstructor
class TocGenerator {
	
	def static void main(String[] args) {
		try {
			if (args.length > 1 || args.helpRequested) {
				System.err.println('''
					Usage: java -jar toc_generator.jar [directory]
					
					The optional argument [directory] must point to a relative or absolute file
					system directory in which the source files are searched. The default is to
					search the current directory. The output is always generated in the current
					directory.
				''')
				System.exit(1)
			} else if (args.length == 1) {
				new TocGenerator(args.get(0)).generate
			} else {
				new TocGenerator('.').generate
			}
		} catch (Throwable t) {
			t.printStackTrace
			System.exit(1)
		}
	}
	
	private static def isHelpRequested(String[] args) {
		if (args.length == 1) {
			#{'h', '-h', 'help', '-help', '--help'}.contains(args.get(0))
		}
	}
	
	val String sourceDirName
	
	def generate() {
		val sourceDir = new File(sourceDirName)
		if (!sourceDir.isDirectory) {
			System.err.println(sourceDirName + ' is not a directory.')
			System.exit(1)
		}
		val markdownFiles = sourceDir.listFiles[isFile && name.endsWith('.md')].sortBy[name]
		if (markdownFiles.isEmpty) {
			System.err.println('The directory ' + sourceDirName + ' does not contain any Markdown files.')
			System.exit(1)
		}
		
		markdownFiles.forEach[println(name)]
	}
	
}