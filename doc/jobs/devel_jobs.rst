*devel* jobs
==============

A *devel* job is used for continuous integration.
It builds the code and runs the tests to check for regressions.
It operates on a single source repository and is triggered for every
commit to a specific branch.

A variation of this is a *pull request* job.
The only difference is that it is triggered by create a pull request or
changing commits on an existing pull request.

Each build is performed within a clean environment (provided by a Docker
container) which only contains the specific dependencies of packages in the
repository as well as tools needed to perform the build.

The `diagram <devel_call_graph.png>`_ shows the correlation between the various
scripts and templates.

The set of source repositories is identified by the *source build files* in the
ROS build farm configuration repository.
For each *source build file* two separate Jenkins views are created.


Entry points
------------

The following scripts are the entry points for *devel* jobs.
The scripts operate on a specific *source build file* in the ROS build farm
configuration:

* **generate_devel_maintenance_jobs.py** generates a set of jobs on the farm
  which will perform maintenance tasks.

  * The ``reconfigure-jobs`` job will (re-)configure the *devel* and *pull
    request* jobs for each package on a regular basis (e.g. once every day).
  * The ``trigger-jobs`` job is triggered manually to trigger *devel* jobs
    selected by their current build status.

* **generate_devel_jobs.py** invokes *generate_devel_job.py* for every source
  repository matching the criteria from the *source build file*.
* **generate_devel_job.py** generates *devel* and/or *pull request* jobs for a
  specific source repository for each platform and architecture listed in the
  *release build file*.
* **generate_devel_script.py** generates a *shell* script which will run the
  same tasks as the *devel* job for a specific source repository on a
  local machine.


The build process in detail
---------------------------

The actual build is performed within a Docker container in order to only make
the declared dependencies available.
Since the dependencies needed at build time are different from the dependencies
to run / test the code these two tasks use two different Docker containers.

The actual build process starts in the script *create_devel_task_generator.py*.
It generates two Dockerfiles: one to perform the *build-and-install* task and
one to perform the *build-and-test* task.


Build and install
^^^^^^^^^^^^^^^^^

This task is performed by the script *catkin_make_isolated_and_install.py*.
The environment will only contain the *build* dependencies declared by the
packages in the source repository.

The task performs the following steps:

* The content of the source repository is expected to be available in the
  folder *catkin_workspace/src*.
* Removes any *build*, *devel* and *install* folders left over from previous
  runs.
* Invokes
  ``catkin_make_isolated --install -DCATKIN_SKIP_TESTING=1 --catkin-make-args -j1``.

  Since the CMake option ``CATKIN_ENABLE_TESTING`` is not enabled explicitly
  the packages must neither configure any tests nor use any test-only
  dependencies.
  The option ``CATKIN_SKIP_TESTING`` prevents CMake from failing if packages
  violate this restriction and only outputs a CMake warning instead.

  The build is performed single threaded to achieve deterministic build results
  (a different target order could break the build if it lacks correct target
  dependencies) and make errors easier to read.


Build and test
^^^^^^^^^^^^^^

This task is performed by the script *catkin_make_isolated_and_test.py*.
The environment will only contain the *build*, *run* and *test* dependencies
declared by the packages in the source repository.

The task performs the following steps:

* The content of the source repository is expected to be available in the
  folder *catkin_workspace/src*.
* Invokes

  ``catkin_make_isolated --cmake-args -DCATKIN_ENABLE_TESTING=1 -DCATKIN_SKIP_TESTING=0 -DCATKIN_TEST_RESULTS_DIR=path/to/catkin_workspace/test_results --catkin-make-args -j1 run_tests``.

  The XUnit test results for each package will be created in the subfolder
  *test_results* in the catkin workspace and be shown by Jenkins.


Known limitations
^^^^^^^^^^^^^^^^^

Since the Docker container contains the dependencies for all packages of the
tested source repository it can not detect missing dependencies of individual
packages if another package in the same repository has that dependency.


Run the *devel* job locally
---------------------------

In order to use ``ros_buildfarm`` locally you need to
`setup your environment <../environment.rst>`_ with the necessary Python
packages.

The entry point ``generate_devel_script.py`` can be used to generate a shell
script which will perform the same tasks as the build farm.
It requires certain tools to be available on the local machine (e.g. the Python
packages ``catkin_pkg``, ``rosdistro``).

When the generated script is being invoked in runs the *build-and-install* task
as well as the *build-and-test* task in separate Docker containers.
Additionally it invokes the tool ``catkin_test_results --all`` to output a
summary of all tests.


Example invocation
^^^^^^^^^^^^^^^^^^

The following commands run the *devel* job for the *roscpp_core* repository
from ROS *Indigo* for Ubuntu *Trusty* *amd64*:

.. code:: sh

  mkdir /tmp/devel_job
  generate_devel_script.py https://raw.githubusercontent.com/ros-infrastructure/ros_buildfarm_config/master/index.yaml indigo default roscpp_core ubuntu trusty amd64 > /tmp/devel_job/devel_job_indigo_roscpp_core.sh
  cd /tmp/devel_job
  sh devel_job_indigo_roscpp_core.sh
