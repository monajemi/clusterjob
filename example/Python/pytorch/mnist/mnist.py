# DCNN Tranining Example
# Data: MNIST
# Author: Hatef Monajemi (monajemi AT stanford DOT edu)
# Date: Aug 2017
# Stanford, CA

import numpy, os.path
import matplotlib.pyplot as plt
import torch
import torchvision
import torchvision.transforms as transforms
from   torch.autograd import Variable

use_gpu = torch.cuda.is_available()


# Set the seed for pytorch
seed = 1915;
numpy.random.seed(seed)
torch.manual_seed(seed)
if use_gpu:
    torch.cuda.manual_seed(seed)
    print('using GPU')
else:
    print('using CPUs only')


# load data using torchvision and do some transformations
batchSize=4;
transform = transforms.Compose([transforms.ToTensor(),
                                transforms.Normalize((0.5, 0.5, 0.5), (0.5, 0.5, 0.5))
                                ])
training_data   = torchvision.datasets.MNIST(root='./data', train=True , download=True, transform=transform);
test_data       = torchvision.datasets.MNIST(root='./data', train=False, download=True, transform=transform);


# build a trainloader to sample data
trainloader = torch.utils.data.DataLoader(training_data , batch_size=batchSize, shuffle=True, num_workers=2)
testloader  = torch.utils.data.DataLoader(test_data     , batch_size=batchSize, shuffle=True, num_workers=2)

###############################################
## Experiments with images to get familir with
## them
## functions to show image
#from torchvision.utils import make_grid;
#def imshow(img):
#    img = img / 2 + 0.5     # unnormalize
#    npimg = img.numpy()
#    plt.imshow(numpy.transpose(npimg, (1, 2, 0)))
#
#
#
## get some random training images
#dataiter = iter(trainloader)
#images, labels = dataiter.next()
#
## show images
#imshow(make_grid(images))
## print labels
#print(' '.join('%5s' % labels[j] for j in range(4)))
###############################################


# Define a CNN
class CNN(torch.nn.Module):
    def __init__(self):
        super(CNN,self).__init__();
        self.conv1 = torch.nn.Conv2d(1,10,5)   # 1 input Channel, 10 output Channel, 5x5 filter  (28 -> 24)
        self.relu  = torch.nn.ReLU();
        self.pool  = torch.nn.MaxPool2d(2,stride=2);                                            #(24 -> 12)
        self.fc1   = torch.nn.Linear(10*12*12, 120);
        self.fc2   = torch.nn.Linear(120,10);

    def forward(self,x):
        x =  self.pool(self.relu(self.conv1(x)))
        x = x.view(-1,10*12*12);       # reshape it to a row vector
        x = self.relu(self.fc1(x));
        x = self.fc2(x)
        return x;

model = CNN();

if use_gpu:
    model = model.cuda()


# initiate model parameters with the ones we have, if any
if os.path.exists('model_params.pt'):
   model.load_state_dict(torch.load('model_params.pt'))





loss_fn   = torch.nn.CrossEntropyLoss()
optimizer = torch.optim.SGD(model.parameters(), lr=0.001, momentum=0.9)



running_loss = 0.0;
for epoch in range(4):

    for i, data in enumerate(trainloader,0):
        # read inputs and labels
    
        inputs, labels = data;
        # wrap them in Variable
        if use_gpu:
            inputs = Variable(inputs.cuda())
            labels = Variable(labels.cuda())
        else:
            inputs, labels = Variable(inputs), Variable(labels)
        
        # generate prediction
        preds  = model(inputs);
        # compute loss
        loss  = loss_fn(preds,labels);

        # update the weights by backprop algo
        optimizer.zero_grad()    # zero the gradients from previous calls
        loss.backward();         # compute gradient of loss w.r.t all parameters
        optimizer.step();        # This updates all the parameters of the model

        # print some statistics of loss
        running_loss += loss.data[0];
        if i % 2000 == 1999:
            print('loss[%-2i,%6i] -> %3.2f' % (epoch+1,i+1,running_loss))
            running_loss = 0.0;

print('Done training');


###############################################
## Predict for 4 images
#dataiter = iter(testloader)
#images, labels = dataiter.next()
#
## print images
#imshow(torchvision.utils.make_grid(images))
#print('GroundTruth: ', ' '.join('%5s' % labels[j] for j in range(4)))
#
#prediction = model(Variable(images));
#_, predicted = torch.max(prediction.data, 1)
#print('Predicted: ', ' '.join('%5s' % predicted[j][0] for j in range(4)))
###############################################



# Whole data set
correct = 0
total   = 0
for data in testloader:
    inputs, labels = data
    # wrap them in Variable
    if use_gpu:
        inputs = Variable(inputs.cuda())
    else:
        inputs = Variable(inputs)
    prediction = model(inputs);
    _, predicted = torch.max(prediction.data, 1)
    total   += labels.size(0)
    correct += (predicted.cpu() == labels).sum()

print('Accuracy of the network on %i test images of MNIST: %3.2f %%' % (total, 100 * correct / total))



# save the model params for future use:
torch.save(model.state_dict(), 'model_params.pt');
# To reload later
#model = CNN();
#model.load_state_dict(torch.load(PATH))
