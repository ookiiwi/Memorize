import os
from distutils.core import setup

PACKAGE_NAME = 'tei2xslob'

setup(name=PACKAGE_NAME,
      version='1.0',
      description='Converts TEI dictionaries to slob',
      author='Igor Tkach',
      author_email='itkach@gmail.com',
      url='http://github.com/itkach/tei2slob',
      license='GPL3',
      py_modules=[PACKAGE_NAME],
      install_requires=['Slob >= 1.0'],
      zip_safe=False,
      entry_points={'console_scripts': ['{0}={0}:main'.format(PACKAGE_NAME)]})
