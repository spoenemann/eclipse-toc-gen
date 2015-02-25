/*******************************************************************************
 * Copyright (c) 2015 itemis AG (http://www.itemis.eu) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *******************************************************************************/
package org.xtext.tocgen

import java.io.BufferedReader
import java.io.File
import java.io.FileReader
import java.io.FileWriter
import java.io.Writer
import java.util.List
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

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
				new TocGenerator(args.get(0), 'contents').generate
			} else {
				new TocGenerator('.', 'contents').generate
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
	
	private static def ==(char c, CharSequence s) {
		s.length == 1 && c == s.charAt(0)
	}
	
	private static def !=(char c, CharSequence s) {
		s.length != 1 || c != s.charAt(0)
	}
	
	val String sourceDirName
	val String destDirName
	val String fileExtension = '.md'
	val int maxSectionLevel = 3
	
	var int indentLevel
	
	def generate() {
		val sourceDir = new File(sourceDirName)
		if (!sourceDir.isDirectory) {
			System.err.println(sourceDirName + ' is not a directory.')
			System.exit(1)
		}
		val markdownFiles = sourceDir.listFiles[isFile && name.endsWith(fileExtension)]
			.filter[!name.startsWith('index')].sortBy[name]
		if (markdownFiles.isEmpty) {
			System.err.println('The directory ' + sourceDirName + ' does not contain any valid input files.')
			System.exit(1)
		}
		val indexFile = new File(sourceDirName + File.separator + 'index' + fileExtension)
		if (!indexFile.exists) {
			System.err.println('The directory ' + sourceDirName + ' does not contain an index.' + fileExtension + ' file.')
			System.exit(1)
		}
		val docTitle = indexFile.getPart
		
		indentLevel = 0
		var FileWriter output
		try {
			output = new FileWriter('toc.xml')
			output += '''<?xml version="1.0" encoding="ISO-8859-1"?>'''
			output += '''<toc topic="«destDirName»/index.html" label="«docTitle»">'''
			indent(1)
			generateContent(markdownFiles, output)
			indent(-1)
			output += '''</toc>'''
		} finally {
			output?.close
		}
	}
	
	private def generateContent(List<File> markdownFiles, Writer output) {
		var String lastPart = null
		for (file : markdownFiles) {
			val fileName = file.name.substring(0, file.name.length - fileExtension.length)
			val partName = file.getPart
			if (partName != lastPart) {
				if (lastPart != null) {
					indent(-1)
					output += '''</topic>'''
				}
				output += '''<topic href="«destDirName»/«fileName».html" label="«partName»">'''
				indent(1)
			}
			
			var FileReader closeable
			try {
				closeable = new FileReader(file)
				val reader = new BufferedReader(closeable)
				println('Processing file ' + file.name)
				generateContent(fileName, reader, output)
			} finally {
				closeable?.close
			}
			lastPart = partName
		}
		indent(-1)
		output += '''</topic>'''
	}
	
	private def generateContent(String fileName, BufferedReader reader, Writer output) {
		var lastSectionLevel = 0
		var line = reader.getNextSection
		while (line != null) {
			val sectionName = line.sectionName
			if (sectionName != null) {
				val sectionLevel = line.sectionLevel
				if (lastSectionLevel == 0) {
					output += '''<topic href="«destDirName»/«fileName».html" label="«sectionName»">'''
					indent(1)
					lastSectionLevel = 1
				} else if (sectionLevel <= maxSectionLevel) {
					for (var i = sectionLevel; i <= lastSectionLevel; i++) {
						indent(-1)
						output += '''</topic>'''
					}
					val anchor = line.sectionAnchor
					output += '''<topic href="«destDirName»/«fileName».html#«anchor»" label="«sectionName»">'''
					indent(1)
					if (sectionLevel > lastSectionLevel + 1)
						lastSectionLevel = sectionLevel + 1
					else
						lastSectionLevel = sectionLevel
				}
			}				
			line = reader.getNextSection
		}
		for (var i = 1; i <= lastSectionLevel; i++) {
			indent(-1)
			output += '''</topic>'''
		}
	}
	
	private def getPart(File file) {
		var FileReader closeable
		try {
			closeable = new FileReader(file)
			val reader = new BufferedReader(closeable)
			var line = reader.readLine
			var firstLine = true
			while (line != null) {
				if (line == null || firstLine && !line.startsWith('---') || !firstLine && line.startsWith('---'))
					return ""
				if (line.startsWith('part:')) {
					return line.substring(5).trim
				}
				line = reader.readLine
				firstLine = false
			}
		} finally {
			closeable?.close
		}
		return ""
	}
	
	private def getNextSection(BufferedReader reader) {
		var line = reader.readLine
		while (line != null) {
			if (line.startsWith('#'))
				return line
			line = reader.readLine
		}
	}
	
	private def getSectionLevel(String line) {
		var result = 0
		for (var i = 0; i < line.length; i++) {
			if (line.charAt(i) == '#')
				result++
			else
				return result
		}
		return result
	}
	
	private def getSectionName(String line) {
		for (var i = 0; i < line.length; i++) {
			if (line.charAt(i) != '#') {
				val anchorIndex = line.indexOf('{')
				if (anchorIndex >= i)
					return line.substring(i, anchorIndex).trim
				else
					return line.substring(i).trim
			}
		}
	}
	
	private def getSectionAnchor(String line) {
		val anchorStartIndex = line.indexOf('{')
		val anchorEndIndex = line.indexOf('}')
		if (anchorStartIndex >= 0 && anchorEndIndex > anchorStartIndex) {
			val result = line.substring(anchorStartIndex + 1, anchorEndIndex)
			if (result.startsWith('#'))
				return result.substring(1)
			else
				return result
		} else {
			return line.sectionName.toLowerCase.replaceAll('\\W', '-')
		}
	}
	
	private def +=(Writer writer, String line) {
		for (var i = 0; i < indentLevel; i++) {
			writer.write('	')
		}
		writer.write(line)
		writer.write('\n')
	}
	
	private def indent(int x) {
		indentLevel = indentLevel + x
	}
	
}