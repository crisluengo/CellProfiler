"""<b>LoadSingleImage</b> loads a single image, which will be used for all image cycles.
<hr>
Note: for most purposes, you will probably want to use the Load Images
module, not this one.

Tells CellProfiler where to retrieve a single image and gives the image a
meaningful name for the other modules to access.  The module only
executes the first time through the pipeline, and thereafter the image
is accessible to all subsequent cycles being processed. This is
particularly useful for loading an image like an Illumination correction
image to be used by the CorrectIllumination_Apply module. Note: Actually,
you can load four 'single' images using this module.

See also <b>LoadImages</b>.

"""
__version__="Revision: $1 "

#CellProfiler is distributed under the GNU General Public License.
#See the accompanying file LICENSE for details.
#
#Developed by the Broad Institute
#Copyright 2003-2009
#
#Please see the AUTHORS file for credits.
#
#Website: http://www.cellprofiler.org

import re
import os
import uuid

import cellprofiler.cpimage as cpi
import cellprofiler.cpmodule as cpm
import cellprofiler.preferences as cpprefs
import cellprofiler.settings as cps
from loadimages import LoadImagesImageProvider

DIR_DEFAULT_IMAGE_FOLDER = "Default input folder"
DIR_DEFAULT_OUTPUT_FOLDER = "Default output folder"
DIR_CUSTOM_FOLDER = "Custom folder"

FD_FILE_NAME = "FileName"
FD_IMAGE_NAME = "ImageName"
FD_KEY = "Key"
FD_REMOVE_BUTTON = "RemoveButton"

class LoadSingleImage(cpm.CPModule):

    module_name = "LoadSingleImage"
    category = "File Processing"
    variable_revision_number = 1
    def create_settings(self):
        """Create the settings during initialization
        
        """
        self.dir_choice = cps.Choice("Which folder contains the image files?",
                                     [DIR_DEFAULT_IMAGE_FOLDER,
                                      DIR_DEFAULT_OUTPUT_FOLDER,
                                      DIR_CUSTOM_FOLDER], doc = '''It is best to store your illumination function
                                      in either the input or output folder, so that the correct image is loaded into 
                                      the pipeline and typos are avoided.  If you must store it in another folder, 
                                      select 'Custom'.''')
        self.custom_directory = cps.Text("What is the name of the folder containing the image files?",".")
        self.file_settings = []
        self.add_file()
        self.add_button = cps.DoSomething("Add another file to be loaded",
                                          "Add", self.add_file)

    def add_file(self):
        """Add settings for another file to the list"""
        new_key = uuid.uuid1()
        dictionary = {
                      FD_KEY: new_key,
                      FD_FILE_NAME: cps.Text("What image file do you want to load? Include the extension like .tif","None"),
                      FD_IMAGE_NAME: cps.FileImageNameProvider("What do you want to call that image?",
                                                               "OrigBlue"),
                      FD_REMOVE_BUTTON: cps.DoSomething("Remove the above image and file",
                                                        "Remove", 
                                                        self.remove_file,
                                                        new_key)
                      }
        self.file_settings.append(dictionary)
    
    def remove_file(self, key):
        """Remove settings for the file whose FD_KEY entry is the indicated key
        
        key - should be the FD_KEY entry of the dictionary for the file
              to be removed from self.file_settings
        """
        index = [d[FD_KEY] for d in self.file_settings].index(key)
        del self.file_settings[index]
        
    def settings(self):
        """Return the settings in the order in which they appear in a pipeline file"""
        result = [self.dir_choice, self.custom_directory]
        for file_setting in self.file_settings:
            result += [file_setting[FD_FILE_NAME], 
                       file_setting[FD_IMAGE_NAME]]
        return result

    def prepare_settings(self, setting_values):
        """Adjust the file_settings depending on how many files there are"""
        count = (len(setting_values)-2)/2
        while len(self.file_settings) > count:
            self.remove_file(self.file_settings[0][FD_KEY])
        while len(self.file_settings) < count:
            self.add_file()

    def visible_settings(self):
        result = [self.dir_choice]
        if self.dir_choice == DIR_CUSTOM_FOLDER:
            result += [self.custom_directory]
        for file_setting in self.file_settings:
            result += [file_setting[FD_FILE_NAME], file_setting[FD_IMAGE_NAME],
                       file_setting[FD_REMOVE_BUTTON] ]
        result.append(self.add_button)
        return result 

    def get_base_directory(self):
        if self.dir_choice == DIR_DEFAULT_IMAGE_FOLDER:
            base_directory = cpprefs.get_default_image_directory()
        elif self.dir_choice == DIR_DEFAULT_OUTPUT_FOLDER:
            base_directory = cpprefs.get_default_output_directory()
        elif self.dir_choice == DIR_CUSTOM_FOLDER:
            base_directory = self.custom_directory.value
            if (base_directory[:2] == '.'+ os.sep or
                (os.altsep and base_directory[:2] == '.'+os.altsep)):
                # './filename' -> default_image_folder/filename
                base_directory = os.path.join(cpprefs.get_default_image_directory(),
                                              base_directory[:2])
            elif (base_directory[:2] == '&'+ os.sep or
                  (os.altsep and base_directory[:2] == '&'+os.altsep)):
                base_directory = os.path.join(cpprefs.get_default_output_directory(),
                                              base_directory[:2])
        return base_directory
    
    def get_file_names(self, workspace):
        """Get the files for the current image set
        
        workspace - workspace for current image set
        
        returns a dictionary of image_name keys and file path values
        """
        result = {}
        for file_setting in self.file_settings:
            file_pattern = file_setting[FD_FILE_NAME].value
            file_name = workspace.measurements.apply_metadata(file_pattern)
            result[file_setting[FD_IMAGE_NAME].value] = file_name
                
        return result
            
    def run(self, workspace):
        dict = self.get_file_names(workspace)
        root = self.get_base_directory()
        statistics = [("Image name","File")]
        for image_name in dict.keys():
            provider = LoadImagesImageProvider(image_name, root, 
                                               dict[image_name])
            workspace.image_set.providers.append(provider)
            statistics += [(image_name, dict[image_name])]
        if workspace.frame:
            title = "Load single image: image set # %d"%(workspace.measurements.image_set_number+1)
            figure = workspace.create_or_find_figure(title=title,
                                                     subplots=(1,1))
            figure.subplot_table(0,0, statistics)
    
    def upgrade_settings(self, setting_values, variable_revision_number, module_name, from_matlab):
        if from_matlab and variable_revision_number == 4:
            new_setting_values = list(setting_values)
            # The first setting was blank in Matlab. Now it contains
            # the directory choice
            if setting_values[1] == '.':
                new_setting_values[0] = DIR_DEFAULT_IMAGE_FOLDER
            elif setting_values[1] == '&':
                new_setting_values[0] = DIR_DEFAULT_OUTPUT_FOLDER
            else:
                new_setting_values[0] = DIR_CUSTOM_FOLDER
            #
            # Remove "Do not use" images
            #
            for i in [8, 6, 4]:
                if new_setting_values[i+1] == cps.DO_NOT_USE:
                    del new_setting_values[i:i+2]
            setting_values = new_setting_values
            from_matlab = False
            variable_revision_number = 1
        return setting_values, variable_revision_number, from_matlab

