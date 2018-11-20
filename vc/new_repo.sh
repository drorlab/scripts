#!/bin/bash
# Run an isolated test of the current branch, with a separate codebase and
# environment.

display_usage() {
    echo "Usage: $0 root_code_dir repo_name"
    }


if [ ! $# -eq 2 ]
then
    echo "Incorrect number of arguments provided!"
    display_usage
    exit
fi
root_dir=$1
repo_name=$2


curr_dir=`pwd`
commit=`git rev-parse HEAD`
git_dir="$root_dir/$repo_name"

echo "Making test for $commit at $git_dir"

mkdir -p $git_dir
cd $git_dir
git init --bare

echo \
    "#!/bin/sh
GIT_WORK_TREE=$git_dir git checkout -f $commit" > $git_dir/hooks/post-receive
chmod +x $git_dir/hooks/post-receive

cd $curr_dir
git remote add $repo_name $git_dir
git push $repo_name $commit:refs/head/$repo_name
git remote remove $repo_name

cd $git_dir/src/learning
python setup.py build_ext --inplace 2>build.err 1>build.out
